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


@router.delete("/{article_id}")
def delete_article(
    article_id: int,
    current_user: dict = Depends(require_role("admin", "engineer")),
):
    db = get_db()
    result = db.table("articles").select("id").eq("id", article_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Article not found")
    db.table("articles").delete().eq("id", article_id).execute()
    return {"message": "Article deleted successfully"}