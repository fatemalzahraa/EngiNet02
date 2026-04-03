from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from database import get_db
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/posts", tags=["Posts"])

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

class PostCreate(BaseModel):
    content: str
    image_url: Optional[str] = ""
    linked_course_id: Optional[int] = None
    category: Optional[str] = ""

# GET SMART FEED
@router.get("/feed")
def get_smart_feed(email: str = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("""
            SELECT i.name FROM interests i
            JOIN user_interests ui ON ui.interest_id = i.id
            WHERE ui.user_id = %s
        """, (user["id"],))
        interests = [row["name"] for row in cursor.fetchall()]

        if interests:
            placeholders = ",".join(["%s"] * len(interests))
            cursor.execute(f"""
                SELECT p.*, u.username, u.profile_image, u.role,
                    CASE WHEN p.category = ANY(ARRAY[{placeholders}]::text[]) THEN 1 ELSE 0 END AS relevance
                FROM posts p
                JOIN users u ON p.user_id = u.id
                ORDER BY relevance DESC, p.created_at DESC
            """, interests)
        else:
            cursor.execute("""
                SELECT p.*, u.username, u.profile_image, u.role
                FROM posts p
                JOIN users u ON p.user_id = u.id
                ORDER BY p.created_at DESC
            """)

        posts = cursor.fetchall()
        result = []
        for p in posts:
            post = dict(p)
            post.pop("relevance", None)
            if post.get("linked_course_id"):
                cursor.execute("SELECT * FROM courses WHERE id = %s", (post["linked_course_id"],))
                course = cursor.fetchone()
                post["linked_course"] = dict(course) if course else None
            else:
                post["linked_course"] = None
            result.append(post)
        return result
    finally:
        db.close()

# GET ALL POSTS
@router.get("/")
def get_all_posts():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            SELECT p.*, u.username, u.profile_image, u.role
            FROM posts p
            JOIN users u ON p.user_id = u.id
            ORDER BY p.created_at DESC
        """)
        posts = cursor.fetchall()
        result = []
        for p in posts:
            post = dict(p)
            if post.get("linked_course_id"):
                cursor.execute("SELECT * FROM courses WHERE id = %s", (post["linked_course_id"],))
                course = cursor.fetchone()
                post["linked_course"] = dict(course) if course else None
            else:
                post["linked_course"] = None
            result.append(post)
        return result
    finally:
        db.close()

# CREATE POST (+1 نقطة)
@router.post("/")
def create_post(post: PostCreate, email: str = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, role FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        if user["role"] not in ("engineer", "specialist", "admin"):
            raise HTTPException(status_code=403, detail="Only specialists can create posts")

        cursor.execute("""
            INSERT INTO posts (user_id, content, image_url, linked_course_id, category)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
        """, (user["id"], post.content, post.image_url, post.linked_course_id, post.category))

        new_id = cursor.fetchone()["id"]
        add_points(cursor, user["id"], 1)  # +1 نشر بوست
        db.commit()
        return {"message": "Post created successfully", "post_id": new_id}
    finally:
        db.close()

# LIKE POST (+2 نقاط لصاحب البوست)
@router.post("/{post_id}/like")
def like_post(post_id: int):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT user_id FROM posts WHERE id = %s", (post_id,))
        post = cursor.fetchone()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")

        cursor.execute("UPDATE posts SET likes = likes + 1 WHERE id = %s", (post_id,))
        add_points(cursor, post["user_id"], 2)  # +2 لايك
        db.commit()
        return {"message": "Post liked!"}
    finally:
        db.close()

# DELETE POST
@router.delete("/{post_id}")
def delete_post(post_id: int, email: str = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("SELECT user_id FROM posts WHERE id = %s", (post_id,))
        post = cursor.fetchone()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        if post["user_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="Not authorized to delete this post")

        cursor.execute("DELETE FROM posts WHERE id = %s", (post_id,))
        db.commit()
        return {"message": "Post deleted successfully"}
    finally:
        db.close()

# GET INTERESTS LIST
@router.get("/interests")
def get_interests():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM interests ORDER BY name")
        return cursor.fetchall()
    finally:
        db.close()

# SET USER INTERESTS
@router.post("/interests/set")
def set_user_interests(interest_ids: list[int], email: str = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("DELETE FROM user_interests WHERE user_id = %s", (user["id"],))
        for interest_id in interest_ids:
            cursor.execute(
                "INSERT INTO user_interests (user_id, interest_id) VALUES (%s, %s)",
                (user["id"], interest_id)
            )
        db.commit()
        return {"message": "Interests updated successfully"}
    finally:
        db.close()