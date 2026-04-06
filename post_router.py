from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from dependencies import get_current_user, add_points
from database import get_db

router = APIRouter(prefix="/posts", tags=["Posts"])


class PostCreate(BaseModel):
    content: str
    image_url: Optional[str] = ""
    linked_course_id: Optional[int] = None
    category: Optional[str] = ""


# ── Smart feed ────────────────────────────────────────────
@router.get("/feed")
def get_smart_feed(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            """
            SELECT i.name FROM interests i
            JOIN user_interests ui ON ui.interest_id = i.id
            WHERE ui.user_id = %s
            """,
            (user["id"],),
        )
        interests = [row["name"] for row in cursor.fetchall()]

        if interests:
            placeholders = ",".join(["%s"] * len(interests))
            cursor.execute(
                f"""
                SELECT p.*, u.username, u.profile_image, u.role,
                    CASE WHEN p.category = ANY(ARRAY[{placeholders}]::text[]) THEN 1 ELSE 0 END AS relevance
                FROM posts p
                JOIN users u ON p.user_id = u.id
                ORDER BY relevance DESC, p.created_at DESC
                """,
                interests,
            )
        else:
            cursor.execute(
                """
                SELECT p.*, u.username, u.profile_image, u.role
                FROM posts p
                JOIN users u ON p.user_id = u.id
                ORDER BY p.created_at DESC
                """
            )

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


# ── Get all posts ─────────────────────────────────────────
@router.get("/")
def get_all_posts():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute(
            """
            SELECT p.*, u.username, u.profile_image, u.role
            FROM posts p
            JOIN users u ON p.user_id = u.id
            ORDER BY p.created_at DESC
            """
        )
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


# ── Create post (+1 point) ────────────────────────────────
@router.post("/")
def create_post(post: PostCreate, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, role FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        if user["role"] not in ("engineer", "admin"):
            raise HTTPException(status_code=403, detail="Only engineers and admins can create posts")

        cursor.execute(
            """
            INSERT INTO posts (user_id, content, image_url, linked_course_id, category)
            VALUES (%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (user["id"], post.content, post.image_url, post.linked_course_id, post.category),
        )
        new_id = cursor.fetchone()["id"]
        add_points(cursor, user["id"], 1)
        db.commit()
        return {"message": "Post created successfully", "post_id": new_id}
    finally:
        db.close()


# ── Like post — prevents duplicate likes and self-likes ───
@router.post("/{post_id}/like")
def like_post(post_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        liker = cursor.fetchone()
        if not liker:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("SELECT user_id FROM posts WHERE id = %s", (post_id,))
        post = cursor.fetchone()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")

        if post["user_id"] == liker["id"]:
            raise HTTPException(status_code=400, detail="You cannot like your own post")

        # Prevent duplicate likes
        cursor.execute(
            "SELECT 1 FROM post_likes WHERE post_id = %s AND user_id = %s",
            (post_id, liker["id"]),
        )
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="You already liked this post")

        cursor.execute(
            "INSERT INTO post_likes (post_id, user_id) VALUES (%s, %s)",
            (post_id, liker["id"]),
        )
        cursor.execute("UPDATE posts SET likes = likes + 1 WHERE id = %s", (post_id,))
        add_points(cursor, post["user_id"], 2)
        db.commit()
        return {"message": "Post liked!"}
    finally:
        db.close()


# ── Unlike post ───────────────────────────────────────────
@router.delete("/{post_id}/like")
def unlike_post(post_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        liker = cursor.fetchone()
        if not liker:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            "DELETE FROM post_likes WHERE post_id = %s AND user_id = %s RETURNING 1",
            (post_id, liker["id"]),
        )
        if not cursor.fetchone():
            raise HTTPException(status_code=400, detail="You haven't liked this post")

        cursor.execute(
            "UPDATE posts SET likes = GREATEST(likes - 1, 0) WHERE id = %s",
            (post_id,),
        )

        # Get post owner to deduct points
        cursor.execute("SELECT user_id FROM posts WHERE id = %s", (post_id,))
        post = cursor.fetchone()
        if post:
            cursor.execute(
                "UPDATE users SET points = GREATEST(points - 2, 0) WHERE id = %s",
                (post["user_id"],),
            )

        db.commit()
        return {"message": "Post unliked!"}
    finally:
        db.close()


# ── Delete post ───────────────────────────────────────────
@router.delete("/{post_id}")
def delete_post(post_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id, role FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("SELECT user_id FROM posts WHERE id = %s", (post_id,))
        post = cursor.fetchone()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        if post["user_id"] != user["id"] and user["role"] != "admin":
            raise HTTPException(status_code=403, detail="Not authorized to delete this post")

        cursor.execute("DELETE FROM post_likes WHERE post_id = %s", (post_id,))
        cursor.execute("DELETE FROM posts WHERE id = %s", (post_id,))
        db.commit()
        return {"message": "Post deleted successfully"}
    finally:
        db.close()


# ── Interests ─────────────────────────────────────────────
@router.get("/interests")
def get_interests():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM interests ORDER BY name")
        return cursor.fetchall()
    finally:
        db.close()


@router.post("/interests/set")
def set_user_interests(interest_ids: list[int], current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("DELETE FROM user_interests WHERE user_id = %s", (user["id"],))
        for interest_id in interest_ids:
            cursor.execute(
                "INSERT INTO user_interests (user_id, interest_id) VALUES (%s,%s)",
                (user["id"], interest_id),
            )
        db.commit()
        return {"message": "Interests updated successfully"}
    finally:
        db.close()