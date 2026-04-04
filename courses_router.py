from fastapi import APIRouter, HTTPException, Depends
from database import get_db
from pydantic import BaseModel
from typing import Optional

from dependencies import get_current_user, require_role, add_points

router = APIRouter(prefix="/courses", tags=["Courses"])


class CourseCreate(BaseModel):
    title: str
    instructor_name: str
    instructor_image: Optional[str] = ""
    description: Optional[str] = ""
    category: Optional[str] = ""
    image_url: Optional[str] = ""
    duration_hours: Optional[int] = 0
    rating: Optional[float] = 0.0


# GET ALL COURSES - عام
@router.get("/")
def get_all_courses(search: Optional[str] = None):
    db = get_db()
    try:
        cursor = db.cursor()
        query = "SELECT * FROM courses WHERE 1=1"
        params = []
        if search:
            query += " AND title LIKE %s"
            params.append(f"%{search}%")
        query += " ORDER BY created_at DESC"
        cursor.execute(query, params)
        return cursor.fetchall()
    finally:
        db.close()


# GET COURSE BY ID مع الدروس - عام
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
            (course_id,)
        )
        lessons = cursor.fetchall()
        result = dict(course)
        result["lessons"] = lessons
        return result
    finally:
        db.close()


# ADD COURSE (+20 نقاط) - engineer أو admin فقط
@router.post("/")
def add_course(
    course: CourseCreate,
    current_user: dict = Depends(require_role("engineer", "admin"))
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("""
            INSERT INTO courses (title, instructor_name, instructor_image, description,
                                category, image_url, duration_hours, rating)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            course.title, course.instructor_name, course.instructor_image,
            course.description, course.category, course.image_url,
            course.duration_hours, course.rating
        ))
        new_id = cursor.fetchone()["id"]
        add_points(cursor, user["id"], 20)
        db.commit()
        return {"message": "Course added", "course_id": new_id}
    finally:
        db.close()


# DELETE COURSE - admin فقط
@router.delete("/{course_id}")
def delete_course(
    course_id: int,
    current_user: dict = Depends(require_role("admin"))
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