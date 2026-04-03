from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from database import get_db
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/books", tags=["Books"])

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

class BookCreate(BaseModel):
    title: str
    author: str
    category: str
    description: str
    file_url: str
    language: Optional[str] = "English"
    publish_year: Optional[int] = 2024
    image_url: Optional[str] = ""

@router.get("/")
def get_all_books(search: Optional[str] = None, category: Optional[str] = None):
    db = get_db()
    cursor = db.cursor()
    query = "SELECT * FROM books WHERE 1=1"
    params = []
    if search:
        query += " AND (title LIKE %s OR author LIKE %s)"
        params.extend([f"%{search}%", f"%{search}%"])
    if category:
        query += " AND category LIKE %s"
        params.append(f"%{category}%")
    query += " ORDER BY likes DESC"
    cursor.execute(query, params)
    books = cursor.fetchall()
    db.close()
    return books

@router.get("/{book_id}")
def get_book(book_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM books WHERE id = %s", (book_id,))
    book = cursor.fetchone()
    db.close()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    return book

# ADD BOOK (+10 نقاط)
@router.post("/")
def add_book(book: BookCreate, email: str = Depends(get_current_user)):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
    user = cursor.fetchone()
    if not user:
        db.close()
        raise HTTPException(status_code=404, detail="User not found")

    cursor.execute("""
        INSERT INTO books (title, author, category, description, file_url, language, publish_year, image_url)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    """, (book.title, book.author, book.category, book.description,
          book.file_url, book.language, book.publish_year, book.image_url))
    new_id = cursor.fetchone()["id"]
    add_points(cursor, user["id"], 10)  # +10 نشر كتاب
    db.commit()
    db.close()
    return {"message": "Book added successfully", "book_id": new_id}

@router.post("/{book_id}/like")
def like_book(book_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("UPDATE books SET likes = likes + 1 WHERE id = %s", (book_id,))
    if cursor.rowcount == 0:
        db.close()
        raise HTTPException(status_code=404, detail="Book not found")
    db.commit()
    db.close()
    return {"message": "Book liked!"}

@router.delete("/{book_id}")
def delete_book(book_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("DELETE FROM books WHERE id = %s", (book_id,))
    if cursor.rowcount == 0:
        db.close()
        raise HTTPException(status_code=404, detail="Book not found")
    db.commit()
    db.close()
    return {"message": "Book deleted successfully"}