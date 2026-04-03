from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from database import get_db
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/articles", tags=["Articles"])

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
        query += " AND title LIKE %s"
        params.append(f"%{search}%")
    query += " ORDER BY created_at DESC"
    cursor.execute(query, params)
    articles = cursor.fetchall()
    db.close()
    return articles

# GET ARTICLE BY ID
@router.get("/{article_id}")
def get_article(article_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM articles WHERE id = %s", (article_id,))
    article = cursor.fetchone()
    db.close()
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")
    return article

# ADD ARTICLE (+5 نقاط)
@router.post("/")
def add_article(article: ArticleCreate, email: str = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
    user = cursor.fetchone()
    if not user:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")

    cursor.execute("""
        INSERT INTO articles (title, content, category, image_url, author_name, author_image, rating, pdf_url)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    """, (article.title, article.content, article.category,
          article.image_url, article.author_name, article.author_image,
          article.rating, article.pdf_url))
    new_id = cursor.fetchone()["id"]
    add_points(cursor, user["id"], 5)  # +5 نشر مقالة
    db.commit()
    db.close()
    return {"message": "Article added successfully", "article_id": new_id}

# DELETE ARTICLE
@router.delete("/{article_id}")
def delete_article(article_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("DELETE FROM articles WHERE id = %s", (article_id,))
    if cursor.rowcount == 0:
        db.close()
        raise HTTPException(status_code=404, detail="Article not found")
    db.commit()
    db.close()
    return {"message": "Article deleted successfully"}