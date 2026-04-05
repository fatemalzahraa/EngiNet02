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
from dependencies import (
    SECRET_KEY,
    ALGORITHM,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    get_current_user,
    add_points,
)

# ── Config ────────────────────────────────────────────────
GMAIL_USER = os.getenv("GMAIL_USER", "")
GMAIL_PASSWORD = os.getenv("GMAIL_PASSWORD", "")
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost").split(",")

app = FastAPI(title="EngiNet API", version="2.0")

app.include_router(books_router)
app.include_router(articles_router)
app.include_router(course_router)
app.include_router(profile_router)
app.include_router(post_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory OTP store: { email: { "code": str, "expires": datetime } }
_otp_store: dict = {}


# ── Helpers ───────────────────────────────────────────────
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


# ── Register ──────────────────────────────────────────────
@app.post("/register")
def register(user: User):
    db = get_db()
    try:
        cursor = db.cursor()
        hashed = bcrypt.hashpw(user.password.encode(), bcrypt.gensalt()).decode()
        try:
            cursor.execute(
                "INSERT INTO users (username, email, password, role) VALUES (%s,%s,%s,%s)",
                (user.username, user.email, hashed, user.role),
            )
            db.commit()
        except Exception:
            raise HTTPException(status_code=400, detail="Username or email already exists")
    finally:
        db.close()

    token = create_access_token({"sub": user.email, "role": user.role})
    return {"message": "User created successfully", "access_token": token, "token_type": "bearer"}


# ── Login ─────────────────────────────────────────────────
@app.post("/token")
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM users WHERE email = %s", (form_data.username,))
        user = cursor.fetchone()
    finally:
        db.close()

    if not user:
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    if not bcrypt.checkpw(form_data.password.encode(), user["password"].encode()):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    token = create_access_token({"sub": user["email"], "role": user["role"]})
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": user["role"],
        "username": user["username"],
    }


# ── Me ────────────────────────────────────────────────────
@app.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    return current_user


# ── Forgot Password ───────────────────────────────────────
@app.post("/forgot-password")
def forgot_password(email: str):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, username FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
    finally:
        db.close()

    if not user:
        return {"message": "If this email exists, a reset code has been sent"}

    code = str(secrets.randbelow(900000) + 100000)
    _otp_store[email] = {
        "code": code,
        "expires": datetime.now(timezone.utc) + timedelta(minutes=15),
    }

    body = f"""Hello {user['username']},

Your EngiNet password reset code is:

  {code}

This code expires in 15 minutes.

— EngiNet Team"""

    send_email(email, "EngiNet - Password Reset Code", body)
    return {"message": "If this email exists, a reset code has been sent"}


# ── Verify OTP ────────────────────────────────────────────
class VerifyOTPRequest(BaseModel):
    email: str
    code: str


@app.post("/verify-otp")
def verify_otp(data: VerifyOTPRequest):
    entry = _otp_store.get(data.email)
    if not entry:
        raise HTTPException(status_code=400, detail="No reset code found for this email")
    if datetime.now(timezone.utc) > entry["expires"]:
        _otp_store.pop(data.email, None)
        raise HTTPException(status_code=400, detail="Reset code has expired")
    if entry["code"] != data.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")
    return {"message": "Code verified", "valid": True}


# ── Reset Password ────────────────────────────────────────
class ResetPasswordRequest(BaseModel):
    email: str
    code: str
    new_password: str


@app.post("/reset-password")
def reset_password(data: ResetPasswordRequest):
    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    entry = _otp_store.get(data.email)
    if not entry:
        raise HTTPException(status_code=400, detail="No reset code found — request a new one")
    if datetime.now(timezone.utc) > entry["expires"]:
        _otp_store.pop(data.email, None)
        raise HTTPException(status_code=400, detail="Reset code has expired")
    if entry["code"] != data.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (data.email,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Email not found")
        hashed = bcrypt.hashpw(data.new_password.encode(), bcrypt.gensalt()).decode()
        cursor.execute("UPDATE users SET password = %s WHERE email = %s", (hashed, data.email))
        db.commit()
    finally:
        db.close()

    _otp_store.pop(data.email, None)
    return {"message": "Password updated successfully"}


# ── Engineers ─────────────────────────────────────────────
@app.get("/users/engineers")
def get_engineers():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            "SELECT id, username, profile_image, points, university "
            "FROM users WHERE role = 'engineer' ORDER BY points DESC"
        )
        return cursor.fetchall()
    finally:
        db.close()


# ── Questions ─────────────────────────────────────────────
# Schema: id, title, content, username, profile_image, category, likes, created_at
class QuestionRequest(BaseModel):
    title: str
    content: str
    category: str = ""


# Schema: id, question_id, username, content, is_accepted, likes, created_at
class AnswerRequest(BaseModel):
    content: str


@app.post("/questions")
def create_question(q: QuestionRequest, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            "SELECT username, profile_image FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        cursor.execute(
            "INSERT INTO questions (username, profile_image, title, content, category) "
            "VALUES (%s,%s,%s,%s,%s)",
            (user["username"], user["profile_image"], q.title, q.content, q.category),
        )
        db.commit()
        return {"message": "Question posted successfully"}
    finally:
        db.close()


@app.get("/questions")
def get_questions():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            "SELECT id, title, content, category, likes, created_at, username, profile_image "
            "FROM questions ORDER BY created_at DESC"
        )
        return cursor.fetchall()
    finally:
        db.close()


@app.post("/questions/{question_id}/answers")
def post_answer(
    question_id: int,
    a: AnswerRequest,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            "SELECT username FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            "INSERT INTO answers (question_id, username, content) VALUES (%s,%s,%s)",
            (question_id, user["username"], a.content),
        )
        db.commit()
        return {"message": "Answer posted successfully"}
    finally:
        db.close()


@app.get("/questions/{question_id}/answers")
def get_answers(question_id: int):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            "SELECT id, content, likes, is_accepted, created_at, username "
            "FROM answers WHERE question_id = %s ORDER BY created_at ASC",
            (question_id,),
        )
        return cursor.fetchall()
    finally:
        db.close()


@app.post("/questions/{question_id}/answers/{answer_id}/accept")
def accept_answer(
    question_id: int,
    answer_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            "SELECT username FROM users WHERE email = %s", (current_user["email"],)
        )
        user = cursor.fetchone()

        cursor.execute("SELECT username FROM questions WHERE id = %s", (question_id,))
        question = cursor.fetchone()
        if not question or question["username"] != user["username"]:
            raise HTTPException(status_code=403, detail="Only question owner can accept answers")

        cursor.execute(
            "UPDATE answers SET is_accepted = true WHERE id = %s RETURNING id",
            (answer_id,),
        )
        answer = cursor.fetchone()
        if not answer:
            raise HTTPException(status_code=404, detail="Answer not found")

        db.commit()
        return {"message": "Answer accepted"}
    finally:
        db.close()


# ── Notifications ─────────────────────────────────────────
# Schema: id, user_id, message, is_read, created_at
@app.get("/notifications")
def get_notifications(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        cursor.execute(
            "SELECT id, message, is_read, created_at FROM notifications "
            "WHERE user_id = %s ORDER BY created_at DESC",
            (user["id"],),
        )
        return cursor.fetchall()
    finally:
        db.close()


@app.post("/notifications/read")
def mark_notifications_read(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        cursor.execute(
            "UPDATE notifications SET is_read = true WHERE user_id = %s", (user["id"],)
        )
        db.commit()
        return {"message": "All notifications marked as read"}
    finally:
        db.close()