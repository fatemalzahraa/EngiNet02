import os
import pickle
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
from recommender import train_model
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


def _delete_otp(email: str) -> None:
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("DELETE FROM otp_codes WHERE email = %s", (email,))
        db.commit()
    finally:
        db.close()
def get_popular_content(cursor):
    cursor.execute("SELECT * FROM courses ORDER BY COALESCE(rating,0) DESC LIMIT 10")
    courses = cursor.fetchall()
    cursor.execute("SELECT * FROM books ORDER BY COALESCE(likes,0) DESC LIMIT 10")
    books = cursor.fetchall()
    cursor.execute("SELECT * FROM articles ORDER BY COALESCE(rating,0) DESC LIMIT 10")
    articles = cursor.fetchall()
    return {"courses": courses, "books": books, "articles": articles}

@app.post("/register")
def register(user: User):
    db = get_db()
    try:
        cursor = db.cursor()

        hashed = bcrypt.hashpw(
            user.password.encode(),
            bcrypt.gensalt()
        ).decode()

        try:
            cursor.execute(
                """
                INSERT INTO users
                (username, email, password, role)
                VALUES (%s,%s,%s,%s)
                RETURNING id
                """,
                (
                    user.username,
                    user.email,
                    hashed,
                    user.role,
                ),
            )

            new_user = cursor.fetchone()
            db.commit()

        except Exception:
            raise HTTPException(
                status_code=400,
                detail="Username or email already exists"
            )

    finally:
        db.close()

    token = create_access_token({
        "sub": user.email,
        "role": user.role
    })

    return {
        "message": "User created successfully",
        "user_id": new_user["id"],
        "access_token": token,
        "token_type": "bearer"
    }

class StudentProfileRequest(BaseModel):
    university: str = ""
    specialty: str = ""
    study_year: str = ""
    level: str = ""
    interests: str = ""
    preferred_language: str = ""


@app.post("/student-profile")
def create_student_profile(
    data: StudentProfileRequest,
    current_user: dict = Depends(get_current_user)
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()

        cursor.execute("""
            INSERT INTO student_profiles
            (user_id, university, specialty, study_year, level, interests, preferred_language)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (user_id) DO UPDATE SET
              university = EXCLUDED.university,
              specialty = EXCLUDED.specialty,
              study_year = EXCLUDED.study_year,
              level = EXCLUDED.level,
              interests = EXCLUDED.interests,
              preferred_language = EXCLUDED.preferred_language
        """, (
            user["id"],
            data.university,
            data.specialty,
            data.study_year,
            data.level,
            data.interests,
            data.preferred_language,
        ))

        db.commit()
        return {"message": "Student profile saved"}
    finally:
        db.close()


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
def create_engineer_profile(
    data: EngineerProfileRequest,
    current_user: dict = Depends(get_current_user)
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()

        cursor.execute("""
            INSERT INTO engineer_profiles
            (user_id, university, specialty, experience_years, skills, bio, location, linkedin, github, website)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (user_id) DO UPDATE SET
              university = EXCLUDED.university,
              specialty = EXCLUDED.specialty,
              experience_years = EXCLUDED.experience_years,
              skills = EXCLUDED.skills,
              bio = EXCLUDED.bio,
              location = EXCLUDED.location,
              linkedin = EXCLUDED.linkedin,
              github = EXCLUDED.github,
              website = EXCLUDED.website
        """, (
            user["id"],
            data.university,
            data.specialty,
            data.experience_years,
            data.skills,
            data.bio,
            data.location,
            data.linkedin,
            data.github,
            data.website,
        ))

        db.commit()
        return {"message": "Engineer profile saved"}
    finally:
        db.close()


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
    if not user.get("password"):
        raise HTTPException(status_code=400, detail="This account uses Supabase Auth. Please log in via the app.")
    if not bcrypt.checkpw(form_data.password.encode(), user["password"].encode()):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    token = create_access_token({"sub": user["email"], "role": user["role"]})
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": user["role"],
        "username": user["username"],
    }


@app.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    return current_user


@app.post("/forgot-password")
def forgot_password(email: str):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, email FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        if not user:
            return {"message": "If this email exists, a reset link has been sent"}

        token = secrets.token_urlsafe(32)
        expires_at = datetime.utcnow() + timedelta(minutes=30)
        cursor.execute(
            "INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES (%s, %s, %s)",
            (user["id"], token, expires_at)
        )
        db.commit()
        reset_link = f"https://your-domain.com/reset-password-link?token={token}"
        send_email(to=user["email"], subject="Reset your password", body=f"Click the link to reset your password:\n{reset_link}")
        print("RESET LINK:", reset_link)
        return {"message": "If this email exists, a reset link has been sent"}
    finally:
        db.close()


class VerifyOTPRequest(BaseModel):
    email: str
    code: str


@app.post("/verify-otp")
def verify_otp(data: VerifyOTPRequest):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT code, expires_at FROM otp_codes WHERE email = %s", (data.email,))
        entry = cursor.fetchone()
    finally:
        db.close()

    if not entry:
        raise HTTPException(status_code=400, detail="No reset code found for this email")

    expires_at = entry["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc) > expires_at:
        _delete_otp(data.email)
        raise HTTPException(status_code=400, detail="Reset code has expired")
    if entry["code"] != data.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    return {"message": "Code verified", "valid": True}


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


@app.post("/reset-password-link")
def reset_password_link(data: ResetPasswordRequest):
    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            "SELECT prt.id, prt.user_id FROM password_reset_tokens prt WHERE prt.token = %s AND prt.used = 0 AND prt.expires_at > NOW()",
            (data.token,)
        )
        reset_token = cursor.fetchone()
        if not reset_token:
            raise HTTPException(status_code=400, detail="Invalid or expired reset link")

        hashed_password = bcrypt.hashpw(data.new_password.encode(), bcrypt.gensalt()).decode()
        cursor.execute("UPDATE users SET password = %s WHERE id = %s", (hashed_password, reset_token["user_id"]))
        cursor.execute("UPDATE password_reset_tokens SET used = 1 WHERE id = %s", (reset_token["id"],))
        db.commit()
        return {"message": "Password updated successfully"}
    finally:
        db.close()


@app.get("/users/engineers")
def get_engineers():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, username, profile_image, points, university FROM users WHERE role = 'engineer' ORDER BY points DESC")
        return cursor.fetchall()
    finally:
        db.close()


class QuestionRequest(BaseModel):
    title: str
    content: str
    category: str = ""


class AnswerRequest(BaseModel):
    content: str


@app.post("/questions")
def create_question(q: QuestionRequest, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, username, profile_image FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        cursor.execute(
            "INSERT INTO questions (user_id, username, profile_image, title, content, category) VALUES (%s, %s, %s, %s, %s, %s)",
            (user["id"], user["username"], user["profile_image"], q.title, q.content, q.category),
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
        cursor.execute("SELECT id, title, content, category, likes, created_at, username, profile_image FROM questions ORDER BY created_at DESC")
        return cursor.fetchall()
    finally:
        db.close()


@app.post("/questions/{question_id}/answers")
def post_answer(question_id: int, a: AnswerRequest, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, username FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        cursor.execute("SELECT id FROM questions WHERE id = %s", (question_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Question not found")
        cursor.execute(
            "INSERT INTO answers (question_id, user_id, username, content) VALUES (%s,%s,%s,%s)",
            (question_id, user["id"], user["username"], a.content),
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
            "SELECT id, content, likes, is_accepted, created_at, username FROM answers WHERE question_id = %s ORDER BY is_accepted DESC, likes DESC, created_at ASC",
            (question_id,),
        )
        return cursor.fetchall()
    finally:
        db.close()


@app.post("/questions/{question_id}/answers/{answer_id}/accept")
def accept_answer(question_id: int, answer_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT username FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        cursor.execute("SELECT username FROM questions WHERE id = %s", (question_id,))
        question = cursor.fetchone()
        if not question or question["username"] != user["username"]:
            raise HTTPException(status_code=403, detail="Only question owner can accept answers")
        cursor.execute("UPDATE answers SET is_accepted = true WHERE id = %s RETURNING id", (answer_id,))
        answer = cursor.fetchone()
        if not answer:
            raise HTTPException(status_code=404, detail="Answer not found")
        db.commit()
        return {"message": "Answer accepted"}
    finally:
        db.close()


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
            "SELECT id, message, is_read, created_at FROM notifications WHERE user_id = %s ORDER BY created_at DESC",
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
        cursor.execute("UPDATE notifications SET is_read = true WHERE user_id = %s", (user["id"],))
        db.commit()
        return {"message": "All notifications marked as read"}
    finally:
        db.close()


@app.get("/recommendations")
def get_recommendations(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_id = user["id"]
        model, users, items, user_idx, item_idx, matrix = train_model(db)

        if model is None:
            return get_popular_content(cursor)

        if user_id not in user_idx:
            return get_popular_content(cursor)

        u_idx = user_idx[user_id]

        result = model.recommend(
          userid=u_idx,
          user_items=matrix[u_idx],
          N=100,
          filter_already_liked_items=False,
         )
        recommended_ids, scores = result

        predictions = []
        for j in range(len(recommended_ids)):
            predictions.append(
                (items[int(recommended_ids[j])], float(scores[j]))
            )

        courses, books, articles = [], [], []
        for item_id, score in predictions:
            content_type, content_id = item_id.split("_", 1)
            if content_type == "course" and len(courses) < 10:
                courses.append(int(content_id))
            elif content_type == "book" and len(books) < 10:
                books.append(int(content_id))
            elif content_type == "article" and len(articles) < 10:
                articles.append(int(content_id))

        if not courses:
            cursor.execute("SELECT id FROM courses ORDER BY COALESCE(rating,0) DESC LIMIT 10")
            courses = [r["id"] for r in cursor.fetchall()]
        if not books:
            cursor.execute("SELECT id FROM books ORDER BY COALESCE(likes,0) DESC LIMIT 10")
            books = [r["id"] for r in cursor.fetchall()]
        if not articles:
            cursor.execute("SELECT id FROM articles ORDER BY COALESCE(rating,0) DESC LIMIT 10")
            articles = [r["id"] for r in cursor.fetchall()]

        return {
            "courses": fetch_by_ids(cursor, "courses", courses),
            "books": fetch_by_ids(cursor, "books", books),
            "articles": fetch_by_ids(cursor, "articles", articles),
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()
def fetch_by_ids(cursor, table, ids):
    if not ids:
        return []

    cursor.execute(f"SELECT * FROM {table} WHERE id = ANY(%s)", (ids,))
    return cursor.fetchall()

@app.post("/interact")
def record_interaction(
    content_type: str,
    content_id: int,
    interaction_type: str,
    current_user: dict = Depends(get_current_user)
):
    scores = {"view": 1, "like": 3, "save": 4, "complete": 5}
    score = scores.get(interaction_type, 1)

    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT id, %s, %s, %s, %s FROM users WHERE email = %s
            ON CONFLICT DO NOTHING
        """, (content_type, content_id, interaction_type, score, current_user["email"]))
        db.commit()
    finally:
        db.close()
    return {"status": "recorded"}
