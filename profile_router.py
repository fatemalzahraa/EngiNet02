from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from database import get_db
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/profile", tags=["Profile"])

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

class UpdateProfile(BaseModel):
    bio: Optional[str] = None
    profile_image: Optional[str] = None
    university: Optional[str] = None

# GET PROFILE
@router.get("/me")
def get_my_profile(email: str = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
    user = cursor.fetchone()
    db.close()
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

# UPDATE PROFILE
@router.put("/me")
def update_my_profile(data: UpdateProfile, email: str = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    if data.bio is not None:
        cursor.execute("UPDATE users SET bio = %s WHERE email = %s", (data.bio, email))
    if data.profile_image is not None:
        cursor.execute("UPDATE users SET profile_image = %s WHERE email = %s", (data.profile_image, email))
    if data.university is not None:
        cursor.execute("UPDATE users SET university = %s WHERE email = %s", (data.university, email))
    db.commit()
    db.close()
    return {"message": "Profile updated successfully"}

# GET USER ENROLLED COURSES
@router.get("/my-courses")
def get_my_courses(email: str = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
    user = cursor.fetchone()
    if not user:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")
    cursor.execute("""
        SELECT DISTINCT c.* FROM courses c
        JOIN lessons l ON l.course_id = c.id
        JOIN lesson_progress lp ON lp.lesson_id = l.id
        WHERE lp.user_id = %s
    """, (user["id"],))
    courses = cursor.fetchall()
    db.close()
    return courses