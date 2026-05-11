import os
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from supabase import create_client
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
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

@router.put("/update")
async def update_profile_full(
    username: str = Form(...),
    email: str = Form(...),
    bio: str = Form(""),
    phone: str = Form(""),
    university: str = Form(""),
    specialty: str = Form(""),
    location: str = Form(""),
    linkedin: str = Form(""),
    github: str = Form(""),
    website: str = Form(""),
    skills: str = Form(""),
    show_email: bool = Form(False),
    image: UploadFile | None = File(None),
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

        profile_image_url = None

        if image:
            file_ext = image.filename.split(".")[-1]
            file_path = f"profile-images/{user['id']}_{username}.{file_ext}"
            file_bytes = await image.read()

            supabase.storage.from_("profiles").upload(
                path=file_path,
                file=file_bytes,
                file_options={
                    "content-type": image.content_type,
                    "upsert": "true",
                },
            )

            profile_image_url = supabase.storage.from_("profiles").get_public_url(
                file_path
            )

        if profile_image_url:
            cursor.execute("""
                UPDATE users
                SET username=%s, email=%s, bio=%s, phone=%s, university=%s,
                    specialty=%s, location=%s, linkedin=%s, github=%s,
                    website=%s, skills=%s, show_email=%s, profile_image=%s
                WHERE id=%s
            """, (
                username, email, bio, phone, university,
                specialty, location, linkedin, github,
                website, skills, show_email, profile_image_url,
                user["id"],
            ))
        else:
            cursor.execute("""
                UPDATE users
                SET username=%s, email=%s, bio=%s, phone=%s, university=%s,
                    specialty=%s, location=%s, linkedin=%s, github=%s,
                    website=%s, skills=%s, show_email=%s
                WHERE id=%s
            """, (
                username, email, bio, phone, university,
                specialty, location, linkedin, github,
                website, skills, show_email,
                user["id"],
            ))

        db.commit()

        return {
            "message": "Profile updated",
            "profile_image": profile_image_url,
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        db.close()


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
    is_completed: bool = False,
    watched_seconds: int = 0,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
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

        cursor.execute(
            """
            INSERT INTO lesson_progress (
                user_id, lesson_id, is_completed, watched_seconds
            )
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (user_id, lesson_id)
            DO UPDATE SET
                is_completed = EXCLUDED.is_completed OR lesson_progress.is_completed,
                watched_seconds = GREATEST(
                    lesson_progress.watched_seconds,
                    EXCLUDED.watched_seconds
                )
            """,
            (user["id"], lesson_id, is_completed, watched_seconds),
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
def get_lesson_progress(
    course_id: int,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
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

        cursor.execute(
            """
            SELECT lp.lesson_id, lp.is_completed, lp.watched_seconds
            FROM lesson_progress lp
            JOIN lessons l ON l.id = lp.lesson_id
            WHERE lp.user_id = %s
              AND l.course_id = %s
            """,
            (user["id"], course_id),
        )

        rows = cursor.fetchall()

        return {
            str(row["lesson_id"]): {
                "completed": bool(row["is_completed"]),
                "watched_seconds": row["watched_seconds"] or 0,
            }
            for row in rows
        }

    finally:
        db.close()