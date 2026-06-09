from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form
from database import get_db
from pydantic import BaseModel
from typing import Optional, List
from dependencies import require_role, add_points_supabase
from supabase import create_client
import os
import time
import json

router = APIRouter(prefix="/courses", tags=["Courses"])

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase_admin = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


class CourseCreate(BaseModel):
    title: str
    instructor_name: str
    instructor_image: Optional[str] = ""
    description: Optional[str] = ""
    category: Optional[str] = ""
    image_url: Optional[str] = ""
    duration_hours: Optional[int] = 0
    rating: Optional[float] = 0.0


class LessonCreate(BaseModel):
    title: str
    video_url: Optional[str] = ""
    duration_minutes: Optional[int] = 0
    duration_seconds: Optional[int] = 0
    order_index: Optional[int] = 0


@router.get("/")
def get_all_courses(search: Optional[str] = None):
    db = get_db()
    query = db.table("courses").select("*")
    if search:
        query = query.ilike("title", f"%{search}%")
    return query.order("created_at", desc=True).execute().data


@router.get("/{course_id}")
def get_course(course_id: int):
    db = get_db()
    course_result = db.table("courses").select("*").eq("id", course_id).execute()
    if not course_result.data:
        raise HTTPException(status_code=404, detail="Course not found")
    course = course_result.data[0]
    lessons = db.table("lessons").select("*").eq("course_id", course_id).order("order_index").execute().data
    course["lessons"] = lessons
    return course


@router.post("/")
def add_course(
    course: CourseCreate,
    current_user: dict = Depends(require_role("engineer", "admin")),
):
    db = get_db()
    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    result = db.table("courses").insert({
        "title": course.title,
        "instructor_name": course.instructor_name,
        "instructor_image": course.instructor_image,
        "description": course.description,
        "category": course.category,
        "image_url": course.image_url,
        "duration_hours": course.duration_hours,
        "rating": course.rating,
    }).execute()

    new_id = result.data[0]["id"]
    add_points_supabase(db, user_id, 20)
    return {"message": "Course added", "course_id": new_id}


@router.post("/{course_id}/lessons")
def add_lesson(
    course_id: int,
    lesson: LessonCreate,
    current_user: dict = Depends(require_role("engineer", "admin")),
):
    db = get_db()
    course_result = db.table("courses").select("id").eq("id", course_id).execute()
    if not course_result.data:
        raise HTTPException(status_code=404, detail="Course not found")

    result = db.table("lessons").insert({
        "course_id": course_id,
        "title": lesson.title,
        "video_url": lesson.video_url,
        "duration_minutes": lesson.duration_minutes,
        "duration_seconds": lesson.duration_seconds,
        "order_index": lesson.order_index,
    }).execute()

    new_id = result.data[0]["id"]
    return {"message": "Lesson added", "lesson_id": new_id}


@router.post("/create-with-videos")
async def create_course_with_videos(
    title: str = Form(...),
    description: str = Form(""),
    video_titles_json: str = Form(...),
    video_durations_json: str = Form("[]"),
    course_image: UploadFile = File(...),
    videos: List[UploadFile] = File(...),
    category: Optional[str] = Form(None),
    current_user: dict = Depends(require_role("engineer", "admin")),
):
    db = get_db()

    video_titles = json.loads(video_titles_json)
    video_durations = json.loads(video_durations_json)

    if len(video_titles) != len(videos):
        raise HTTPException(status_code=400, detail="Video titles count does not match videos count")

    user_result = db.table("users").select("id, username, profile_image").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    timestamp = int(time.time() * 1000)

    image_bytes = await course_image.read()
    image_name = course_image.filename.replace(" ", "_")
    image_path = f"{user['id']}/{timestamp}_{image_name}"
    supabase_admin.storage.from_("course-images").upload(
        image_path, image_bytes, {"content-type": course_image.content_type},
    )
    image_url = supabase_admin.storage.from_("course-images").get_public_url(image_path)

    total_duration_seconds = 0
    for d in video_durations:
        try:
            total_duration_seconds += int(d)
        except Exception:
            pass
    duration_hours = round(total_duration_seconds / 3600, 2) if total_duration_seconds > 0 else len(videos)

    course_result = db.table("courses").insert({
        "title": title,
        "instructor_name": user["username"],
        "instructor_image": user.get("profile_image") or "",
        "description": description,
        "category": category or "",
        "image_url": image_url,
        "duration_hours": duration_hours,
        "rating": 0.0,
    }).execute()

    course_id = course_result.data[0]["id"]

    for i, video in enumerate(videos):
        video_bytes = await video.read()
        video_name = video.filename.replace(" ", "_")
        video_path = f"{user['id']}/{course_id}/{timestamp}_{i + 1}_{video_name}"
        supabase_admin.storage.from_("course-videos").upload(
            video_path, video_bytes, {"content-type": video.content_type},
        )
        video_url = supabase_admin.storage.from_("course-videos").get_public_url(video_path)

        duration_seconds = (
            int(video_durations[i])
            if i < len(video_durations) and str(video_durations[i]).isdigit()
            else 0
        )

        db.table("lessons").insert({
            "course_id": course_id,
            "title": video_titles[i],
            "video_url": video_url,
            "duration_minutes": 0,
            "duration_seconds": duration_seconds,
            "order_index": i + 1,
        }).execute()

    add_points_supabase(db, user["id"], 20)
    return {"message": "Course added with videos", "course_id": course_id}


@router.post("/{course_id}/start")
def start_course(
    course_id: int,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
):
    db = get_db()
    if not db.table("courses").select("id").eq("id", course_id).execute().data:
        raise HTTPException(status_code=404, detail="Course not found")

    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    existing = db.table("student_courses").select("id").eq("user_id", user_id).eq("course_id", course_id).execute()
    if not existing.data:
        db.table("student_courses").insert({"user_id": user_id, "course_id": course_id}).execute()
    return {"message": "Course started"}


@router.delete("/{course_id}")
def delete_course(
    course_id: int,
    current_user: dict = Depends(require_role("admin")),
):
    db = get_db()
    if not db.table("courses").select("id").eq("id", course_id).execute().data:
        raise HTTPException(status_code=404, detail="Course not found")
    db.table("courses").delete().eq("id", course_id).execute()
    return {"message": "Course deleted"}