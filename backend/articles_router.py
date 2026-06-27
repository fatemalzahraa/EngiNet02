from fastapi import APIRouter, HTTPException, Depends
from database import get_db
from pydantic import BaseModel
from typing import Optional
from dependencies import get_current_user, require_role, add_points_supabase

router = APIRouter(prefix="/articles", tags=["Articles"])


class ArticleCreate(BaseModel):
    title: str
    content: str
    category: Optional[str] = ""
    image_url: Optional[str] = ""
    author_name: Optional[str] = ""
    author_image: Optional[str] = ""
    rating: Optional[float] = 0.0
    pdf_url: Optional[str] = ""


class ArticleUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    pdf_url: Optional[str] = None


@router.get("/")
def get_all_articles(search: Optional[str] = None):
    db = get_db()
    query = db.table("articles").select("*")
    if search:
        query = query.ilike("title", f"%{search}%")
    return query.order("created_at", desc=True).execute().data


@router.get("/{article_id}")
def get_article(article_id: int):
    db = get_db()
    result = db.table("articles").select("*").eq("id", article_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Article not found")
    return result.data[0]


@router.post("/")
def add_article(article: ArticleCreate, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    result = db.table("articles").insert({
        "title": article.title,
        "content": article.content,
        "category": article.category,
        "image_url": article.image_url,
        "author_name": article.author_name,
        "author_image": article.author_image,
        "rating": article.rating,
        "pdf_url": article.pdf_url,
    }).execute()

    new_id = result.data[0]["id"]
    add_points_supabase(db, user_id, 5)
    return {"message": "Article added successfully", "article_id": new_id}


@router.put("/{article_id}")
def update_article(
    article_id: int,
    article: ArticleUpdate,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id, username, role").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    existing = db.table("articles").select("id, author_name").eq("id", article_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Article not found")

    if existing.data[0].get("author_name") != user["username"] and user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Not allowed to edit this article")

    update_data = {k: v for k, v in article.dict(exclude_unset=True).items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    db.table("articles").update(update_data).eq("id", article_id).execute()
    return {"message": "Article updated successfully"}


@router.delete("/{article_id}")
def delete_article(
    article_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id, username, role").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    result = db.table("articles").select("id, author_name").eq("id", article_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Article not found")

    if result.data[0].get("author_name") != user["username"] and user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Not allowed to delete this article")

    db.table("articles").delete().eq("id", article_id).execute()
    return {"message": "Article deleted successfully"}