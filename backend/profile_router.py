import os
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from supabase import create_client
from pydantic import BaseModel
from typing import Optional
from dependencies import get_current_user, require_role
from database import get_db

router = APIRouter(prefix="/profile", tags=["Profile"])


class UpdateProfile(BaseModel):
    bio: Optional[str] = None
    profile_image: Optional[str] = None
    university: Optional[str] = None


SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


# ── Update full profile (with optional image upload) ─────
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

    # Get user by email
    user_res = db.table("users").select("id").eq("email", current_user["email"]).single().execute()
    if not user_res.data:
        raise HTTPException(status_code=404, detail="User not found")

    user_id = user_res.data["id"]
    profile_image_url = None

    # Upload image if provided
    if image:
        file_ext = image.filename.split(".")[-1]
        file_path = f"profile-images/{user_id}_{username}.{file_ext}"
        file_bytes = await image.read()

        supabase.storage.from_("profiles").upload(
            path=file_path,
            file=file_bytes,
            file_options={
                "content-type": image.content_type,
                "upsert": "true",
            },
        )

        profile_image_url = supabase.storage.from_("profiles").get_public_url(file_path)

    # Build update payload
    update_data = {
        "username": username,
        "email": email,
        "bio": bio,
        "phone": phone,
        "university": university,
        "specialty": specialty,
        "location": location,
        "linkedin": linkedin,
        "github": github,
        "website": website,
        "skills": skills,
        "show_email": show_email,
    }
    if profile_image_url:
        update_data["profile_image"] = profile_image_url

    result = db.table("users").update(update_data).eq("id", user_id).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to update profile")

    return {
        "message": "Profile updated",
        "profile_image": profile_image_url,
    }


# ── Get my profile ────────────────────────────────────────
@router.get("/me")
def get_my_profile(current_user: dict = Depends(get_current_user)):
    db = get_db()

    result = db.table("users").select(
        "id, username, email, role, bio, profile_image, points, university"
    ).eq("email", current_user["email"]).single().execute()

    if not result.data:
        raise HTTPException(status_code=404, detail="User not found")

    return result.data


# ── Update my profile (partial) ───────────────────────────
@router.put("/me")
def update_my_profile(data: UpdateProfile, current_user: dict = Depends(get_current_user)):
    db = get_db()

    update_data = {}
    if data.bio is not None:
        update_data["bio"] = data.bio
    if data.profile_image is not None:
        update_data["profile_image"] = data.profile_image
    if data.university is not None:
        update_data["university"] = data.university

    if update_data:
        db.table("users").update(update_data).eq("email", current_user["email"]).execute()

    return {"message": "Profile updated successfully"}


# ── Get courses where user has lesson progress ────────────
@router.get("/my-courses")
def get_my_courses(current_user: dict = Depends(get_current_user)):
    db = get_db()

    user_res = db.table("users").select("id").eq("email", current_user["email"]).single().execute()
    if not user_res.data:
        raise HTTPException(status_code=404, detail="User not found")

    user_id = user_res.data["id"]

    # Get lesson IDs completed by user
    progress_res = db.table("lesson_progress").select("lesson_id").eq("user_id", user_id).execute()
    lesson_ids = [row["lesson_id"] for row in (progress_res.data or [])]

    if not lesson_ids:
        return []

    # Get course IDs from those lessons
    lessons_res = db.table("lessons").select("course_id").in_("id", lesson_ids).execute()
    course_ids = list({row["course_id"] for row in (lessons_res.data or [])})

    if not course_ids:
        return []

    # Get courses
    courses_res = db.table("courses").select("*").in_("id", course_ids).execute()
    return courses_res.data or []


# ── Mark lesson as complete / incomplete ──────────────────
@router.post("/lesson-progress")
def save_lesson_progress(
    lesson_id: int,
    is_completed: bool = False,
    watched_seconds: int = 0,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
):
    db = get_db()

    user_res = db.table("users").select("id").eq("email", current_user["email"]).single().execute()
    if not user_res.data:
        raise HTTPException(status_code=404, detail="User not found")

    user_id = user_res.data["id"]

    existing = supabase.table("lesson_progress").select("*").eq("user_id", user_id).eq("lesson_id", lesson_id).execute()

    if existing.data:
        current = existing.data[0]
        new_completed = is_completed or current.get("is_completed", False)
        new_seconds = max(watched_seconds, current.get("watched_seconds") or 0)

        supabase.table("lesson_progress").update({
            "is_completed": new_completed,
            "watched_seconds": new_seconds,
        }).eq("user_id", user_id).eq("lesson_id", lesson_id).execute()
    else:
        supabase.table("lesson_progress").insert({
            "user_id": user_id,
            "lesson_id": lesson_id,
            "is_completed": is_completed,
            "watched_seconds": watched_seconds,
        }).execute()

    return {"message": "Progress saved"}


@router.get("/lesson-progress/{course_id}")
def get_lesson_progress(
    course_id: int,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
):
    db = get_db()

    user_res = db.table("users").select("id").eq("email", current_user["email"]).single().execute()
    if not user_res.data:
        raise HTTPException(status_code=404, detail="User not found")

    user_id = user_res.data["id"]

    lessons_res = supabase.table("lessons").select("id").eq("course_id", course_id).execute()
    lesson_ids = [row["id"] for row in (lessons_res.data or [])]

    if not lesson_ids:
        return {}

    progress_res = supabase.table("lesson_progress").select(
        "lesson_id, is_completed, watched_seconds"
    ).eq("user_id", user_id).in_("lesson_id", lesson_ids).execute()

    return {
        str(row["lesson_id"]): {
            "completed": bool(row["is_completed"]),
            "watched_seconds": row["watched_seconds"] or 0,
        }
        for row in (progress_res.data or [])
    }
# ── Get lesson progress for a course ─────────────────────
@router.get("/lesson-progress/{course_id}")
def get_lesson_progress(
    course_id: int,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
):
    db = get_db()

    user_res = db.table("users").select("id").eq("email", current_user["email"]).single().execute()
    if not user_res.data:
        raise HTTPException(status_code=404, detail="User not found")

    user_id = user_res.data["id"]

    # Get lessons for this course
    lessons_res = db.table("lessons").select("id").eq("course_id", course_id).execute()
    lesson_ids = [row["id"] for row in (lessons_res.data or [])]

    if not lesson_ids:
        return {}

    # Get progress for these lessons
    progress_res = db.table("lesson_progress").select(
        "lesson_id, is_completed, watched_seconds"
    ).eq("user_id", user_id).in_("lesson_id", lesson_ids).execute()

    return {
        str(row["lesson_id"]): {
            "completed": bool(row["is_completed"]),
            "watched_seconds": row["watched_seconds"] or 0,
        }
        for row in (progress_res.data or [])
    }