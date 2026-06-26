from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from dependencies import get_current_user, add_points_supabase
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

    user = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    interests_data = db.table("user_interests")\
        .select("interests(name)")\
        .eq("user_id", user["id"])\
        .execute().data

    interests = [row["interests"]["name"] for row in interests_data if row.get("interests")]

    posts = db.table("posts")\
        .select("*, users(username, profile_image, role)")\
        .order("created_at", desc=True)\
        .execute().data

    # ترتيب حسب الاهتمامات
    if interests:
        posts.sort(key=lambda p: 0 if p.get("category") in interests else 1)

    # إضافة linked_course لكل post
    result = []
    for post in posts:
        if post.get("linked_course_id"):
            course = db.table("courses")\
                .select("*")\
                .eq("id", post["linked_course_id"])\
                .single().execute().data
            post["linked_course"] = course
        else:
            post["linked_course"] = None
        result.append(post)

    return result


# ── Get all posts ─────────────────────────────────────────
@router.get("/")
def get_all_posts():
    db = get_db()

    posts = db.table("posts")\
        .select("*, users(username, profile_image, role)")\
        .order("created_at", desc=True)\
        .execute().data

    result = []
    for post in posts:
        if post.get("linked_course_id"):
            course = db.table("courses")\
                .select("*")\
                .eq("id", post["linked_course_id"])\
                .single().execute().data
            post["linked_course"] = course
        else:
            post["linked_course"] = None
        result.append(post)

    return result


# ── Create post (+1 point) ────────────────────────────────
@router.post("/")
def create_post(post: PostCreate, current_user: dict = Depends(get_current_user)):
    db = get_db()

    user = db.table("users").select("id, role").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user["role"] not in ("engineer", "admin"):
        raise HTTPException(status_code=403, detail="Only engineers and admins can create posts")

    new_post = db.table("posts").insert({
        "user_id": user["id"],
        "content": post.content,
        "image_url": post.image_url,
        "linked_course_id": post.linked_course_id,
        "category": post.category,
    }).execute().data[0]

    add_points_supabase(db, user["id"], 1)

    return {"message": "Post created successfully", "post_id": new_post["id"]}


# ── Like post ─────────────────────────────────────────────
@router.post("/{post_id}/like")
def like_post(post_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()

    liker = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not liker:
        raise HTTPException(status_code=404, detail="User not found")

    post = db.table("posts").select("user_id").eq("id", post_id).single().execute().data
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post["user_id"] == liker["id"]:
        raise HTTPException(status_code=400, detail="You cannot like your own post")

    existing = db.table("post_likes")\
        .select("id")\
        .eq("post_id", post_id)\
        .eq("user_id", liker["id"])\
        .execute().data
    if existing:
        raise HTTPException(status_code=400, detail="You already liked this post")

    db.table("post_likes").insert({"post_id": post_id, "user_id": liker["id"]}).execute()

    current_post = db.table("posts").select("likes").eq("id", post_id).single().execute().data
    db.table("posts").update({"likes": (current_post["likes"] or 0) + 1}).eq("id", post_id).execute()

    add_points_supabase(db, post["user_id"], 2)

    return {"message": "Post liked!"}


# ── Unlike post ───────────────────────────────────────────
@router.delete("/{post_id}/like")
def unlike_post(post_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()

    liker = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not liker:
        raise HTTPException(status_code=404, detail="User not found")

    existing = db.table("post_likes")\
        .select("id")\
        .eq("post_id", post_id)\
        .eq("user_id", liker["id"])\
        .execute().data
    if not existing:
        raise HTTPException(status_code=400, detail="You haven't liked this post")

    db.table("post_likes")\
        .delete()\
        .eq("post_id", post_id)\
        .eq("user_id", liker["id"])\
        .execute()

    current_post = db.table("posts").select("likes, user_id").eq("id", post_id).single().execute().data
    new_likes = max((current_post["likes"] or 1) - 1, 0)
    db.table("posts").update({"likes": new_likes}).eq("id", post_id).execute()

    # خصم النقاط من صاحب المنشور
    owner = db.table("users").select("points").eq("id", current_post["user_id"]).single().execute().data
    if owner:
        new_points = max((owner["points"] or 2) - 2, 0)
        db.table("users").update({"points": new_points}).eq("id", current_post["user_id"]).execute()

    return {"message": "Post unliked!"}


# ── Delete post ───────────────────────────────────────────
@router.delete("/{post_id}")
def delete_post(post_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()

    user = db.table("users").select("id, role").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    post = db.table("posts").select("user_id").eq("id", post_id).single().execute().data
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post["user_id"] != user["id"] and user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to delete this post")

    db.table("post_likes").delete().eq("post_id", post_id).execute()
    db.table("posts").delete().eq("id", post_id).execute()

    return {"message": "Post deleted successfully"}


# ── Interests ─────────────────────────────────────────────
@router.get("/interests")
def get_interests():
    db = get_db()
    return db.table("interests").select("*").order("name").execute().data


@router.post("/interests/set")
def set_user_interests(interest_ids: list[int], current_user: dict = Depends(get_current_user)):
    db = get_db()

    user = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    db.table("user_interests").delete().eq("user_id", user["id"]).execute()

    if interest_ids:
        db.table("user_interests").insert([
            {"user_id": user["id"], "interest_id": iid} for iid in interest_ids
        ]).execute()

    return {"message": "Interests updated successfully"}