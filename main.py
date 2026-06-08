import os
import secrets
import smtplib
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import bcrypt
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from jose import jwt
from pydantic import BaseModel

from articles_router import router as articles_router
from books_router import router as books_router
from courses_router import router as course_router
from database import get_db
from models import User
from post_router import router as post_router
from profile_router import router as profile_router
from questions_router import router as question_router
from recommendations_router import router as recommendations_router
from search_router import router as search_router

from dependencies import (
    SECRET_KEY,
    ALGORITHM,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    get_current_user,
    add_points,
)

GMAIL_USER = os.getenv("GMAIL_USER", "")
GMAIL_PASSWORD = os.getenv("GMAIL_PASSWORD", "")

_origins_env = os.getenv("ALLOWED_ORIGINS", "").strip()
ALLOWED_ORIGINS = [o.strip() for o in _origins_env.split(",") if o.strip()] if _origins_env else ["*"]

app = FastAPI(title="EngiNet API", version="2.0")

app.include_router(books_router)
app.include_router(articles_router)
app.include_router(course_router)
app.include_router(profile_router)
app.include_router(post_router)
app.include_router(question_router)
app.include_router(recommendations_router)
app.include_router(search_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def send_email(to: str, subject: str, body: str) -> None:
    if not GMAIL_USER or not GMAIL_PASSWORD:
        raise HTTPException(status_code=500, detail="Email service is not configured")
    msg = MIMEMultipart()
    msg["Subject"] = subject
    msg["From"] = GMAIL_USER
    msg["To"] = to
    msg.attach(MIMEText(body, "plain"))
    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(GMAIL_USER, GMAIL_PASSWORD)
            server.send_message(msg)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {e}")


# ── /register ──────────────────────────────────────────────
@app.post("/register")
def register(user: User):
    db = get_db()

    hashed = bcrypt.hashpw(user.password.encode(), bcrypt.gensalt()).decode()

    try:
        result = db.table("users").insert({
            "username": user.username,
            "email": user.email,
            "password": hashed,
            "role": user.role,
        }).execute()
    except Exception:
        raise HTTPException(status_code=400, detail="Username or email already exists")

    new_user = result.data[0]

    # user_id artık JWT içine de ekleniyor
    token = create_access_token({
        "sub": user.email,
        "role": user.role,
        "user_id": new_user["id"],
    })

    return {
        "message": "User created successfully",
        "user_id": new_user["id"],
        "access_token": token,
        "token_type": "bearer",
    }


# ── /token (login) ─────────────────────────────────────────
@app.post("/token")
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    db = get_db()
    result = db.table("users").select("*").eq("email", form_data.username).execute()
    users = result.data

    if not users:
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    user = users[0]

    if not user.get("password"):
        raise HTTPException(status_code=400, detail="This account uses Supabase Auth. Please log in via the app.")
    if not bcrypt.checkpw(form_data.password.encode(), user["password"].encode()):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    # user_id artık hem JWT içinde hem response'da
    token = create_access_token({
        "sub": user["email"],
        "role": user["role"],
        "user_id": user["id"],
    })
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": user["role"],
        "username": user["username"],
        "user_id": user["id"],
    }


# ── /me ────────────────────────────────────────────────────
@app.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    return current_user


# ── /student-profile ───────────────────────────────────────
class StudentProfileRequest(BaseModel):
    university: str = ""
    specialty: str = ""
    study_year: str = ""
    level: str = ""
    interests: str = ""
    preferred_language: str = ""


@app.post("/student-profile")
def create_student_profile(data: StudentProfileRequest, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db.table("student_profiles").upsert({
        "user_id": user["id"],
        "university": data.university,
        "specialty": data.specialty,
        "study_year": data.study_year,
        "level": data.level,
        "interests": data.interests,
        "preferred_language": data.preferred_language,
    }, on_conflict="user_id").execute()

    return {"message": "Student profile saved"}


# ── /engineer-profile ──────────────────────────────────────
class EngineerProfileRequest(BaseModel):
    university: str = ""
    specialty: str = ""
    experience_years: int = 0
    skills: str = ""
    bio: str = ""
    location: str = ""
    linkedin: str = ""
    github: str = ""
    website: str = ""


@app.post("/engineer-profile")
def create_engineer_profile(data: EngineerProfileRequest, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db.table("engineer_profiles").upsert({
        "user_id": user["id"],
        "university": data.university,
        "specialty": data.specialty,
        "experience_years": data.experience_years,
        "skills": data.skills,
        "bio": data.bio,
        "location": data.location,
        "linkedin": data.linkedin,
        "github": data.github,
        "website": data.website,
    }, on_conflict="user_id").execute()

    return {"message": "Engineer profile saved"}


# ── /forgot-password ───────────────────────────────────────
class ForgotPasswordRequest(BaseModel):
    email: str


@app.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest):
    db = get_db()

    result = db.table("users").select("id, email").eq("email", data.email).execute()

    if not result.data:
        return {"message": "If this email exists, a reset code has been sent"}

    code = f"{secrets.randbelow(1000000):06d}"
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()

    db.table("otp_codes").delete().eq("email", data.email).execute()

    db.table("otp_codes").insert({
        "email": data.email,
        "code": code,
        "expires_at": expires_at,
    }).execute()

    send_email(
        to=data.email,
        subject="EngiNet Password Reset Code",
        body=f"Your password reset code is: {code}\n\nThis code expires in 10 minutes.",
    )

    return {"message": "If this email exists, a reset code has been sent"}


# ── /verify-otp ────────────────────────────────────────────
class VerifyOTPRequest(BaseModel):
    email: str
    code: str


@app.post("/verify-otp")
def verify_otp(data: VerifyOTPRequest):
    db = get_db()
    result = db.table("otp_codes").select("code, expires_at").eq("email", data.email).execute()
    if not result.data:
        raise HTTPException(status_code=400, detail="No reset code found for this email")

    entry = result.data[0]
    expires_at = datetime.fromisoformat(entry["expires_at"])
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc) > expires_at:
        db.table("otp_codes").delete().eq("email", data.email).execute()
        raise HTTPException(status_code=400, detail="Reset code has expired")
    if entry["code"] != data.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    return {"message": "Code verified", "valid": True}


# ── /reset-password-link ───────────────────────────────────
class ResetPasswordRequest(BaseModel):
    email: str
    code: str
    new_password: str


@app.post("/reset-password-link")
def reset_password_link(data: ResetPasswordRequest):
    if len(data.new_password) < 6:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least 6 characters",
        )

    db = get_db()

    result = db.table("otp_codes") \
        .select("code, expires_at") \
        .eq("email", data.email) \
        .execute()

    if not result.data:
        raise HTTPException(status_code=400, detail="No reset code found")

    entry = result.data[0]

    expires_at = datetime.fromisoformat(entry["expires_at"])
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if datetime.now(timezone.utc) > expires_at:
        db.table("otp_codes").delete().eq("email", data.email).execute()
        raise HTTPException(status_code=400, detail="Reset code has expired")

    if entry["code"] != data.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    user_result = db.table("users").select("id").eq("email", data.email).execute()

    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")

    hashed = bcrypt.hashpw(
        data.new_password.encode(),
        bcrypt.gensalt(),
    ).decode()

    db.table("users") \
        .update({"password": hashed}) \
        .eq("id", user_result.data[0]["id"]) \
        .execute()

    db.table("otp_codes").delete().eq("email", data.email).execute()

    return {"message": "Password updated successfully"}

# ── /users/engineers ───────────────────────────────────────
@app.get("/users/engineers")
def get_engineers():
    db = get_db()
    result = db.table("users").select("id, username, profile_image, points, university").eq("role", "engineer").order("points", desc=True).execute()
    return result.data


# ── /notifications ─────────────────────────────────────────
@app.get("/notifications")
def get_notifications(current_user: dict = Depends(get_current_user)):
    db = get_db()
    user = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    result = db.table("notifications").select("id, message, is_read, created_at").eq("user_id", user["id"]).order("created_at", desc=True).execute()
    return result.data


@app.post("/notifications/read")
def mark_notifications_read(current_user: dict = Depends(get_current_user)):
    db = get_db()
    user = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db.table("notifications").update({"is_read": True}).eq("user_id", user["id"]).execute()
    return {"message": "All notifications marked as read"}


# ── /interact ──────────────────────────────────────────────
@app.post("/interact")
def record_interaction(
    content_type: str,
    content_id: int,
    interaction_type: str,
    current_user: dict = Depends(get_current_user),
):
    scores = {"view": 1, "like": 3, "save": 4, "complete": 5}
    score = scores.get(interaction_type, 1)

    db = get_db()
    user = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db.table("user_interactions").upsert({
        "user_id": user["id"],
        "content_type": content_type,
        "content_id": content_id,
        "interaction_type": interaction_type,
        "score": score,
    }, on_conflict="user_id,content_type,content_id").execute()

    return {"status": "recorded"}