from fastapi import APIRouter, HTTPException
from database import get_db
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter(prefix="/courses", tags=["Courses"])

class LessonCreate(BaseModel):
    title: str
    video_url: str
    duration_minutes: Optional[int] = 0

class CourseCreate(BaseModel):
    title: str
    instructor_name: str
    instructor_image: Optional[str] = ""
    description: Optional[str] = ""
    category: Optional[str] = ""
    image_url: Optional[str] = ""
    duration_hours: Optional[int] = 0
    rating: Optional[float] = 0.0

# GET ALL COURSES
@router.get("/")
def get_all_courses(search: Optional[str] = None):
    db = get_db()
    cursor = db.cursor()
    query = "SELECT * FROM courses WHERE 1=1"
    params = []
    if search:
        query += " AND title LIKE ?"
        params.append(f"%{search}%")
    query += " ORDER BY created_at DESC"
    cursor.execute(query, params)
    courses = cursor.fetchall()
    db.close()
    return [dict(c) for c in courses]

# GET COURSE BY ID WITH LESSONS
@router.get("/{course_id}")
def get_course(course_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM courses WHERE id = ?", (course_id,))
    course = cursor.fetchone()
    if not course:
        db.close()
        raise HTTPException(status_code=404, detail="Course not found")
    cursor.execute("SELECT * FROM lessons WHERE course_id = ? ORDER BY order_index", (course_id,))
    lessons = cursor.fetchall()
    db.close()
    result = dict(course)
    result['lessons'] = [dict(l) for l in lessons]
    return result

# ADD COURSE
@router.post("/")
def add_course(course: CourseCreate):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO courses (title, instructor_name, instructor_image, description,
                            category, image_url, duration_hours, rating)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (course.title, course.instructor_name, course.instructor_image,
          course.description, course.category, course.image_url,
          course.duration_hours, course.rating))
    db.commit()
    new_id = cursor.lastrowid
    db.close()
    return {"message": "Course added", "course_id": new_id}

# DELETE COURSE
@router.delete("/{course_id}")
def delete_course(course_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("DELETE FROM courses WHERE id = ?", (course_id,))
    if cursor.rowcount == 0:
        db.close()
        raise HTTPException(status_code=404, detail="Course not found")
    db.commit()
    db.close()
    return {"message": "Course deleted"}