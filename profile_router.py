from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

# Fixed: import from central dependencies (not from auth.py)
from dependencies import get_current_user
from database import get_db

router = APIRouter(prefix="/profile", tags=["Profile"])


class UpdateProfile(BaseModel):
    bio: Optional[str] = None
    profile_image: Optional[str] = None
    university: Optional[str] = None


# ── Get my profile ────────────────────────────────────────
@router.get("/me")
def get_my_profile(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return {
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "role": user["role"],
            "bio": user["bio"],
            "profile_image": user["profile_image"],
            "points": user["points"],
            "university": user["university"],
        }
    finally:
        db.close()


# ── Update my profile ─────────────────────────────────────
@router.put("/me")
def update_my_profile(data: UpdateProfile, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        fields = []
        values = []
        if data.bio is not None:
            fields.append("bio = %s")
            values.append(data.bio)
        if data.profile_image is not None:
            fields.append("profile_image = %s")
            values.append(data.profile_image)
        if data.university is not None:
            fields.append("university = %s")
            values.append(data.university)

        if fields:
            values.append(current_user["email"])
            cursor.execute(
                f"UPDATE users SET {', '.join(fields)} WHERE email = %s",
                values,
            )
            db.commit()
        return {"message": "Profile updated successfully"}
    finally:
        db.close()


# ── Get courses where user has lesson progress ────────────
@router.get("/my-courses")
def get_my_courses(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        cursor.execute(
            """
            SELECT DISTINCT c.* FROM courses c
            JOIN lessons l ON l.course_id = c.id
            JOIN lesson_progress lp ON lp.lesson_id = l.id
            WHERE lp.user_id = %s
            """,
            (user["id"],),
        )
        return cursor.fetchall()
    finally:
        db.close()


# ── Mark lesson as complete / incomplete ──────────────────
@router.post("/lesson-progress")
def save_lesson_progress(
    lesson_id: int,
    is_completed: bool,
    watched_seconds: int = 0,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()

        cursor.execute(
            "SELECT id FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        completed_value = 1 if is_completed else 0

        cursor.execute(
            """
            INSERT INTO lesson_progress (user_id, lesson_id, is_completed, watched_seconds)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (user_id, lesson_id)
            DO UPDATE SET
                is_completed = EXCLUDED.is_completed,
                watched_seconds = GREATEST(lesson_progress.watched_seconds, EXCLUDED.watched_seconds)
            """,
            (user["id"], lesson_id, completed_value, watched_seconds),
        )

        db.commit()
        return {"message": "Progress saved"}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


# ── Get lesson progress for a course ─────────────────────
@router.get("/lesson-progress/{course_id}")
def get_lesson_progress(course_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            """
            SELECT lp.lesson_id, lp.is_completed
            FROM lesson_progress lp
            JOIN lessons l ON l.id = lp.lesson_id
            WHERE lp.user_id = %s AND l.course_id = %s
            """,
            (user["id"], course_id),
        )
        rows = cursor.fetchall()
        return {row["lesson_id"]: row["is_completed"] for row in rows}
    finally:
        db.close()