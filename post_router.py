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

class PostCreate(BaseModel):
    content: str
    image_url: Optional[str] = ""
    linked_course_id: Optional[int] = None

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
            if post.get('linked_course_id'):
                cursor.execute("SELECT * FROM courses WHERE id = ?", (post['linked_course_id'],))
                course = cursor.fetchone()
                post['linked_course'] = dict(course) if course else None
            else:
                post['linked_course'] = None
            result.append(post)
        return result
    finally:
        db.close()

# DELETE POST (المعدل لحماية المنشورات)
@router.delete("/{post_id}")
def delete_post(post_id: int, email: str = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        
        # 1. جلب ID المستخدم الحالي
        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
            
        # 2. التحقق من ملكية المنشور قبل الحذف
        cursor.execute("SELECT user_id FROM posts WHERE id = ?", (post_id,))
        post = cursor.fetchone()
        
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        
        if post['user_id'] != user['id']:
            raise HTTPException(status_code=403, detail="Not authorized to delete this post")

        # 3. تنفيذ الحذف
        cursor.execute("DELETE FROM posts WHERE id = ?", (post_id,))
        db.commit()
        return {"message": "Post deleted successfully"}
    finally:
        db.close()