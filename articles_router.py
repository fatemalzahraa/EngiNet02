from fastapi import APIRouter, HTTPException, Depends
from database import get_db
from pydantic import BaseModel
from typing import Optional
from dependencies import get_current_user, require_role, add_points

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
    try:
        cursor = db.cursor()
        query = "SELECT * FROM articles WHERE 1=1"
        params = []
        if search:
            query += " AND title ILIKE %s"
            params.append(f"%{search}%")
        query += " ORDER BY created_at DESC"
        cursor.execute(query, params)
        return cursor.fetchall()
    finally:
        db.close()


@router.get("/{article_id}")
def get_article(article_id: int):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM articles WHERE id = %s", (article_id,))
        article = cursor.fetchone()
        if not article:
            raise HTTPException(status_code=404, detail="Article not found")
        return article
    finally:
        db.close()


@router.post("/")
def add_article(article: ArticleCreate, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            """
            INSERT INTO articles (title, content, category, image_url, author_name,
                                  author_image, rating, pdf_url)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (
                article.title, article.content, article.category,
                article.image_url, article.author_name, article.author_image,
                article.rating, article.pdf_url,
            ),
        )
        new_id = cursor.fetchone()["id"]
        add_points(cursor, user["id"], 5)
        db.commit()
        return {"message": "Article added successfully", "article_id": new_id}
    finally:
        db.close()


@router.delete("/{article_id}")
def delete_article(
    article_id: int,
    current_user: dict = Depends(require_role("admin", "engineer")),
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM articles WHERE id = %s", (article_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Article not found")
        cursor.execute("DELETE FROM articles WHERE id = %s", (article_id,))
        db.commit()
        return {"message": "Article deleted successfully"}
    finally:
        db.close()