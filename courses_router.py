from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from database import get_db
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional, List

router = APIRouter(prefix="/courses", tags=["Courses"])

SECRET_KEY = "enginet_super_secret_key_2025"
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return email
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

def add_points(cursor, user_id: int, points: int):
    cursor.execute(
        "UPDATE users SET points = points + %s WHERE id = %s",
        (points, user_id)
    )

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
        query += " AND title LIKE %s"
        params.append(f"%{search}%")
    query += " ORDER BY created_at DESC"
    cursor.execute(query, params)
    courses = cursor.fetchall()
    db.close()
    return courses

# GET COURSE BY ID WITH LESSONS
@router.get("/{course_id}")
def get_course(course_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM courses WHERE id = %s", (course_id,))
    course = cursor.fetchone()
    if not course:
        db.close()
        raise HTTPException(status_code=404, detail="Course not found")
    cursor.execute("SELECT * FROM lessons WHERE course_id = %s ORDER BY order_index", (course_id,))
    lessons = cursor.fetchall()
    db.close()
    result = dict(course)
    result['lessons'] = lessons
    return result

# ADD COURSE (+20 نقاط)
@router.post("/")
def add_course(course: CourseCreate, email: str = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
    user = cursor.fetchone()
    if not user:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")

    cursor.execute("""
        INSERT INTO courses (title, instructor_name, instructor_image, description,
                            category, image_url, duration_hours, rating)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    """, (course.title, course.instructor_name, course.instructor_image,
          course.description, course.category, course.image_url,
          course.duration_hours, course.rating))
    new_id = cursor.fetchone()["id"]
    add_points(cursor, user["id"], 20)  # +20 نشر كورس
    db.commit()
    db.close()
    return {"message": "Course added", "course_id": new_id}

# DELETE COURSE
@router.delete("/{course_id}")
def delete_course(course_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("DELETE FROM courses WHERE id = %s", (course_id,))
    if cursor.rowcount == 0:
        db.close()
        raise HTTPException(status_code=404, detail="Course not found")
    db.commit()
    db.close()
    return {"message": "Course deleted"}