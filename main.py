from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from books_router import router as books_router
import bcrypt
from datetime import datetime, timedelta
from jose import jwt, JWTError
from database import get_db
from models import User
from articles_router import router as articles_router
from profile_router import router as profile_router
from post_router import router as post_router
from courses_router import router as course_router
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# ===================== CONFIG =====================
SECRET_KEY = "enginet_super_secret_key_2025"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

GMAIL_USER = "appenginet2026@gmail.com"
GMAIL_PASSWORD = "omhoqaqptlanznmd"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

app = FastAPI(title="EngiNet API", version="1.0")
app.include_router(books_router)
app.include_router(articles_router)
app.include_router(course_router)
app.include_router(profile_router)
app.include_router(post_router)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===================== HELPERS =====================
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        role: str = payload.get("role")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return {"email": email, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# ===================== REGISTER =====================
@app.post("/register")
def register(user: User):
    db = get_db()
    cursor = db.cursor()
    hashed_password = bcrypt.hashpw(
        user.password.encode("utf-8"),
        bcrypt.gensalt()
    ).decode("utf-8")
    try:
        cursor.execute("""
            INSERT INTO users (username, email, password, role)
            VALUES (?, ?, ?, ?)
        """, (user.username, user.email, hashed_password, user.role))
        db.commit()
    except Exception:
        db.close()
        raise HTTPException(status_code=400, detail="Username or email already exists")
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
    cursor = db.cursor()
    cursor.execute("SELECT * FROM users WHERE email=?", (form_data.username,))
    user = cursor.fetchone()
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
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    user = cursor.fetchone()
    db.close()

    if not user:
        raise HTTPException(status_code=404, detail="Email not found")

    msg = MIMEMultipart()
    msg['Subject'] = "EngiNet - Password Reset Request"
    msg['From'] = GMAIL_USER
    msg['To'] = email

    body = f"""
Hello {user['username']},

We received a request to reset your EngiNet password.

Your registered email: {email}

If you did not request this, please ignore this email.
Your account remains secure.

Best regards,
EngiNet Team
    """
    msg.attach(MIMEText(body, 'plain'))

    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
            server.login(GMAIL_USER, GMAIL_PASSWORD)
            server.send_message(msg)
        return {"message": "Email sent successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")

# ===================== RESET PASSWORD =====================
from pydantic import BaseModel

class ResetPasswordRequest(BaseModel):
    email: str
    new_password: str

@app.post("/reset-password")
def reset_password(data: ResetPasswordRequest):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (data.email,))
    user = cursor.fetchone()

    if not user:
        db.close()
        raise HTTPException(status_code=404, detail="Email not found")

    hashed = bcrypt.hashpw(data.new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    cursor.execute("UPDATE users SET password = ? WHERE email = ?",
                   (hashed, data.email))
    db.commit()
    db.close()
    return {"message": "Password updated successfully"}

# ===================== GET ENGINEERS =====================
@app.get("/users/engineers")
def get_engineers():
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT id, username, profile_image, points, university
        FROM users WHERE role = 'engineer'
    """)
    engineers = cursor.fetchall()
    db.close()
    return [dict(e) for e in engineers]

# ===================== QUESTIONS =====================
from pydantic import BaseModel as PydanticBase

class QuestionRequest(PydanticBase):
    title: str
    content: str
    category: str = ""

class AnswerRequest(PydanticBase):
    content: str

@app.post("/questions")
def create_question(q: QuestionRequest, current_user: dict = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM users WHERE email = ?", (current_user["email"],))
    user = cursor.fetchone()
    
    if not user:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")
    
    cursor.execute("""
        INSERT INTO questions (user_id, title, content, category)
        VALUES (?, ?, ?, ?)
    """, (user["id"], q.title, q.content, q.category))
    db.commit()
    db.close()
    return {"message": "Question posted successfully"}

@app.get("/questions")
def get_questions():
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT q.id, q.title, q.content, q.category, q.likes, q.created_at,
               u.username, u.profile_image
        FROM questions q
        JOIN users u ON q.user_id = u.id
        ORDER BY q.created_at DESC
    """)
    questions = cursor.fetchall()
    db.close()
    return [dict(q) for q in questions]

@app.post("/questions/{question_id}/answers")
def post_answer(question_id: int, a: AnswerRequest, current_user: dict = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()

    # جيب الـ user
    cursor.execute("SELECT id FROM users WHERE email = ?", (current_user["email"],))
    user = cursor.fetchone()

    # أضف الجواب
    cursor.execute("""
        INSERT INTO answers (question_id, user_id, content)
        VALUES (?, ?, ?)
    """, (question_id, user["id"], a.content))

    # جيب صاحب السؤال عشان تبعتله notification
    cursor.execute("SELECT user_id FROM questions WHERE id = ?", (question_id,))
    question = cursor.fetchone()

    if question and question["user_id"] != user["id"]:
        cursor.execute("""
            INSERT INTO notifications (user_id, message)
            VALUES (?, ?)
        """, (question["user_id"], f"👨‍💻 {current_user['email']} answered your question!"))

    db.commit()
    db.close()
    return {"message": "Answer posted successfully"}

@app.get("/questions/{question_id}/answers")
def get_answers(question_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT a.id, a.content, a.likes, a.is_accepted, a.created_at,
               u.username, u.profile_image
        FROM answers a
        JOIN users u ON a.user_id = u.id
        WHERE a.question_id = ?
        ORDER BY a.created_at ASC
    """, (question_id,))
    answers = cursor.fetchall()
    db.close()
    return [dict(a) for a in answers]

# ===================== NOTIFICATIONS =====================
@app.get("/notifications")
def get_notifications(current_user: dict = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM users WHERE email = ?", (current_user["email"],))
    user = cursor.fetchone()
    cursor.execute("""
        SELECT id, message, is_read, created_at
        FROM notifications WHERE user_id = ?
        ORDER BY created_at DESC
    """, (user["id"],))
    notifs = cursor.fetchall()
    db.close()
    return [dict(n) for n in notifs]

@app.post("/notifications/read")
def mark_notifications_read(current_user: dict = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM users WHERE email = ?", (current_user["email"],))
    user = cursor.fetchone()
    cursor.execute("UPDATE notifications SET is_read = 1 WHERE user_id = ?", (user["id"],))
    db.commit()
    db.close()
    return {"message": "All notifications marked as read"}