from fastapi import APIRouter, HTTPException
from database import get_db
from pydantic import BaseModel
from typing import Optional

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

# GET ALL ARTICLES
@router.get("/")
def get_all_articles(search: Optional[str] = None):
    db = get_db()
    cursor = db.cursor()

    query = "SELECT * FROM articles WHERE 1=1"
    params = []

    if search:
        query += " AND title LIKE ?"
        params.append(f"%{search}%")

    query += " ORDER BY created_at DESC"
    cursor.execute(query, params)
    articles = cursor.fetchall()
    db.close()

    return [dict(a) for a in articles]

# GET ARTICLE BY ID
@router.get("/{article_id}")
def get_article(article_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM articles WHERE id = ?", (article_id,))
    article = cursor.fetchone()
    db.close()

    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    return dict(article)

# ADD ARTICLE
@router.post("/")
def add_article(article: ArticleCreate):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO articles (title, content, category, image_url, author_name, author_image, rating, pdf_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (article.title, article.content, article.category,
          article.image_url, article.author_name, article.author_image,
          article.rating, article.pdf_url))
    db.commit()
    new_id = cursor.lastrowid
    db.close()
    return {"message": "Article added successfully", "article_id": new_id}

# DELETE ARTICLE
@router.delete("/{article_id}")
def delete_article(article_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("DELETE FROM articles WHERE id = ?", (article_id,))
    if cursor.rowcount == 0:
        db.close()
        raise HTTPException(status_code=404, detail="Article not found")
    db.commit()
    db.close()
    return {"message": "Article deleted successfully"}