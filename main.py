import os
import smtplib
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import bcrypt
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel

from articles_router import router as articles_router
from books_router import router as books_router
from courses_router import router as course_router
from database import get_db
from models import User
from post_router import router as post_router
from profile_router import router as profile_router

# استيراد من الملف المركزي
from dependencies import (
    SECRET_KEY,
    ALGORITHM,
    get_current_user,
    add_points,
)

# ===================== CONFIG =====================
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
GMAIL_USER = os.getenv("GMAIL_USER", "")
GMAIL_PASSWORD = os.getenv("GMAIL_PASSWORD", "")

app = FastAPI(title="EngiNet API", version="1.0")
app.include_router(books_router)
app.include_router(articles_router)
app.include_router(course_router)
app.include_router(profile_router)
app.include_router(post_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ===================== HELPERS =====================
def create_access_token(data: dict) -> str:
    from jose import jwt
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


# ===================== REGISTER =====================
@app.post("/register")
def register(user: User):
    db = get_db()
    try:
        cursor = db.cursor()
        hashed_password = bcrypt.hashpw(
            user.password.encode("utf-8"),
            bcrypt.gensalt()
        ).decode("utf-8")
        try:
            cursor.execute("""
                INSERT INTO users (username, email, password, role)
                VALUES (%s, %s, %s, %s)
            """, (user.username, user.email, hashed_password, user.role))
            db.commit()
        except Exception:
            raise HTTPException(status_code=400, detail="Username or email already exists")
    finally:
        db.close()

    token = create_access_token({"sub": user.email, "role": user.role})
    return {
        "message": "User created successfully",
        "access_token": token,
        "token_type": "bearer"
    }


# ===================== LOGIN =====================
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

    if not bcrypt.checkpw(form_data.password.encode("utf-8"), user["password"].encode("utf-8")):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    token = create_access_token({"sub": user["email"], "role": user["role"]})
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": user["role"],
        "username": user["username"]
    }


# ===================== GET CURRENT USER =====================
@app.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    return current_user


# ===================== FORGOT PASSWORD =====================
@app.post("/forgot-password")
def forgot_password(email: str):
    if not GMAIL_USER or not GMAIL_PASSWORD:
        raise HTTPException(status_code=500, detail="Email service is not configured")

    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
    finally:
        db.close()

    if not user:
        raise HTTPException(status_code=404, detail="Email not found")

    msg = MIMEMultipart()
    msg["Subject"] = "EngiNet - Password Reset Request"
    msg["From"] = GMAIL_USER
    msg["To"] = email
    body = f"""Hello {user['username']},

We received a request to reset your EngiNet password.

Your registered email: {email}

If you did not request this, please ignore this email.

Best regards,
EngiNet Team"""
    msg.attach(MIMEText(body, "plain"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(GMAIL_USER, GMAIL_PASSWORD)
            server.send_message(msg)
        return {"message": "Email sent successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")


class ResetPasswordRequest(BaseModel):
    email: str
    new_password: str


@app.post("/reset-password")
def reset_password(data: ResetPasswordRequest):
    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM users WHERE email = %s", (data.email,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="Email not found")

        hashed = bcrypt.hashpw(data.new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        cursor.execute("UPDATE users SET password = %s WHERE email = %s", (hashed, data.email))
        db.commit()
    finally:
        db.close()

    return {"message": "Password updated successfully"}


# ===================== GET ENGINEERS =====================
@app.get("/users/engineers")
def get_engineers():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            SELECT id, username, profile_image, points, university
            FROM users WHERE role = 'engineer'
            ORDER BY points DESC
        """)
        return cursor.fetchall()
    finally:
        db.close()


# ===================== QUESTIONS =====================
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
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("""
            INSERT INTO questions (user_id, title, content, category)
            VALUES (%s, %s, %s, %s)
        """, (user["id"], q.title, q.content, q.category))
        db.commit()
        return {"message": "Question posted successfully"}
    finally:
        db.close()


@app.get("/questions")
def get_questions():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            SELECT q.id, q.title, q.content, q.category, q.likes, q.created_at,
                   u.username, u.profile_image
            FROM questions q
            JOIN users u ON q.user_id = u.id
            ORDER BY q.created_at DESC
        """)
        return cursor.fetchall()
    finally:
        db.close()


@app.post("/questions/{question_id}/answers")
def post_answer(
    question_id: int,
    a: AnswerRequest,
    current_user: dict = Depends(get_current_user)
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("""
            INSERT INTO answers (question_id, user_id, content)
            VALUES (%s, %s, %s)
        """, (question_id, user["id"], a.content))

        cursor.execute("SELECT user_id FROM questions WHERE id = %s", (question_id,))
        question = cursor.fetchone()
        if question and question["user_id"] != user["id"]:
            cursor.execute("""
                INSERT INTO notifications (user_id, message)
                VALUES (%s, %s)
            """, (question["user_id"], f"👨‍💻 {current_user['email']} answered your question!"))

        db.commit()
        return {"message": "Answer posted successfully"}
    finally:
        db.close()


@app.get("/questions/{question_id}/answers")
def get_answers(question_id: int):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            SELECT a.id, a.content, a.likes, a.is_accepted, a.created_at,
                   u.username, u.profile_image
            FROM answers a
            JOIN users u ON a.user_id = u.id
            WHERE a.question_id = %s
            ORDER BY a.created_at ASC
        """, (question_id,))
        return cursor.fetchall()
    finally:
        db.close()


@app.post("/questions/{question_id}/answers/{answer_id}/accept")
def accept_answer(
    question_id: int,
    answer_id: int,
    current_user: dict = Depends(get_current_user)
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()

        cursor.execute("SELECT user_id FROM questions WHERE id = %s", (question_id,))
        question = cursor.fetchone()
        if not question or question["user_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="Only question owner can accept answers")

        cursor.execute(
            "UPDATE answers SET is_accepted = true WHERE id = %s RETURNING user_id",
            (answer_id,)
        )
        answer = cursor.fetchone()
        if not answer:
            raise HTTPException(status_code=404, detail="Answer not found")

        add_points(cursor, answer["user_id"], 3)
        cursor.execute("""
            INSERT INTO notifications (user_id, message) VALUES (%s, %s)
        """, (answer["user_id"], "✅ Your answer was accepted!"))
        db.commit()
        return {"message": "Answer accepted"}
    finally:
        db.close()


# ===================== NOTIFICATIONS =====================
@app.get("/notifications")
def get_notifications(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        cursor.execute("""
            SELECT id, message, is_read, created_at
            FROM notifications WHERE user_id = %s
            ORDER BY created_at DESC
        """, (user["id"],))
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
        cursor.execute("UPDATE notifications SET is_read = true WHERE user_id = %s", (user["id"],))
        db.commit()
        return {"message": "All notifications marked as read"}
    finally:
        db.close()