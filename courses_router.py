from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form
from database import get_db
from pydantic import BaseModel
from typing import Optional, List
from dependencies import get_current_user, require_role, add_points
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
    order_index: Optional[int] = 0


@router.get("/")
def get_all_courses(search: Optional[str] = None):
    db = get_db()
    try:
        cursor = db.cursor()
        query = "SELECT * FROM courses WHERE 1=1"
        params = []
        if search:
            query += " AND title ILIKE %s"
            params.append(f"%{search}%")
        query += " ORDER BY created_at DESC"
        cursor.execute(query, params)
        return cursor.fetchall()
    finally:
        db.close()


@router.get("/{course_id}")
def get_course(course_id: int):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM courses WHERE id = %s", (course_id,))
        course = cursor.fetchone()
        if not course:
            raise HTTPException(status_code=404, detail="Course not found")
        cursor.execute(
            "SELECT * FROM lessons WHERE course_id = %s ORDER BY order_index",
            (course_id,),
        )
        lessons = cursor.fetchall()
        result = dict(course)
        result["lessons"] = lessons
        return result
    finally:
        db.close()


@router.post("/")
def add_course(
    course: CourseCreate,
    current_user: dict = Depends(require_role("engineer", "admin")),
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            """
            INSERT INTO courses (title, instructor_name, instructor_image, description,
                                 category, image_url, duration_hours, rating)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (
                course.title, course.instructor_name, course.instructor_image,
                course.description, course.category, course.image_url,
                course.duration_hours, course.rating,
            ),
        )
        new_id = cursor.fetchone()["id"]
        add_points(cursor, user["id"], 20)
        db.commit()
        return {"message": "Course added", "course_id": new_id}
    finally:
        db.close()


@router.post("/{course_id}/lessons")
def add_lesson(
    course_id: int,
    lesson: LessonCreate,
    current_user: dict = Depends(require_role("engineer", "admin")),
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM courses WHERE id = %s", (course_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Course not found")

        cursor.execute(
            """
            INSERT INTO lessons (course_id, title, video_url, duration_minutes, order_index)
            VALUES (%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (course_id, lesson.title, lesson.video_url,
             lesson.duration_minutes, lesson.order_index),
        )
        new_id = cursor.fetchone()["id"]
        db.commit()
        return {"message": "Lesson added", "lesson_id": new_id}
    finally:
        db.close()

@router.post("/create-with-videos")
async def create_course_with_videos(
    title: str = Form(...),
    description: str = Form(""),
    video_titles_json: str = Form(...),
    course_image: UploadFile = File(...),
    videos: List[UploadFile] = File(...),
    current_user: dict = Depends(require_role("engineer", "admin")),
):
    db = get_db()
    try:
        cursor = db.cursor()

        video_titles = json.loads(video_titles_json)

        if len(video_titles) != len(videos):
            raise HTTPException(
                status_code=400,
                detail="Video titles count does not match videos count"
            )

        cursor.execute(
            "SELECT id, username, profile_image FROM users WHERE email = %s",
            (current_user["email"],)
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        timestamp = int(time.time() * 1000)

        image_bytes = await course_image.read()
        image_name = course_image.filename.replace(" ", "_")
        image_path = f"{user['id']}/{timestamp}_{image_name}"

        supabase_admin.storage.from_("course-images").upload(
            image_path,
            image_bytes,
            {"content-type": course_image.content_type}
        )

        image_url = supabase_admin.storage.from_("course-images").get_public_url(image_path)

        cursor.execute(
            """
            INSERT INTO courses (
                title, instructor_name, instructor_image, description,
                category, image_url, duration_hours, rating
            )
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (
                title,
                user["username"],
                user.get("profile_image") or "",
                description,
                "",
                image_url,
                len(videos),
                0.0,
            ),
        )

        course_id = cursor.fetchone()["id"]

        for i, video in enumerate(videos):
            video_bytes = await video.read()
            video_name = video.filename.replace(" ", "_")
            video_path = f"{user['id']}/{course_id}/{timestamp}_{i + 1}_{video_name}"

            supabase_admin.storage.from_("course-videos").upload(
                video_path,
                video_bytes,
                {"content-type": video.content_type}
            )

            video_url = supabase_admin.storage.from_("course-videos").get_public_url(video_path)

            cursor.execute(
                """
                INSERT INTO lessons (
                    course_id, title, video_url, duration_minutes, order_index
                )
                VALUES (%s,%s,%s,%s,%s)
                """,
                (
                    course_id,
                    video_titles[i],
                    video_url,
                    0,
                    i + 1,
                ),
            )

        add_points(cursor, user["id"], 20)
        db.commit()

        return {
            "message": "Course added with videos",
            "course_id": course_id
        }

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()
@router.post("/{course_id}/start")
def start_course(
    course_id: int,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
):
    db = get_db()
    try:
        cursor = db.cursor()

        cursor.execute("SELECT id FROM courses WHERE id = %s", (course_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Course not found")

        cursor.execute(
            "SELECT id FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            """
            INSERT INTO student_courses (user_id, course_id)
            VALUES (%s, %s)
            ON CONFLICT (user_id, course_id) DO NOTHING
            """,
            (user["id"], course_id),
        )

        db.commit()
        return {"message": "Course started"}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()

@router.delete("/{course_id}")
def delete_course(
    course_id: int,
    current_user: dict = Depends(require_role("admin")),
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM courses WHERE id = %s", (course_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Course not found")
        cursor.execute("DELETE FROM courses WHERE id = %s", (course_id,))
        db.commit()
        return {"message": "Course deleted"}
    finally:
        db.close()

@router.post("/{course_id}/start")
def start_course(
    course_id: int,
    current_user: dict = Depends(require_role("student", "engineer", "admin")),
):
    db = get_db()
    try:
        cursor = db.cursor()

        # تأكد الكورس موجود
        cursor.execute("SELECT id FROM courses WHERE id = %s", (course_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Course not found")

        # جيب المستخدم
        cursor.execute(
            "SELECT id FROM users WHERE email = %s",
            (current_user["email"],)
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # تأكد ما مضاف قبل
        cursor.execute(
            """
            SELECT id FROM student_courses
            WHERE user_id = %s AND course_id = %s
            """,
            (user["id"], course_id),
        )

        if not cursor.fetchone():
            cursor.execute(
                """
                INSERT INTO student_courses (user_id, course_id)
                VALUES (%s, %s)
                """,
                (user["id"], course_id),
            )

        db.commit()

        return {"message": "Course started"}

    finally:
        db.close()