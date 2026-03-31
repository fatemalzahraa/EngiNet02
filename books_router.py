from fastapi import APIRouter, HTTPException
from database import get_db
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/books", tags=["Books"])

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
        query += " AND (title LIKE ? OR author LIKE ?)"
        params.extend([f"%{search}%", f"%{search}%"])
    if category:
        query += " AND category LIKE ?"
        params.append(f"%{category}%")
    query += " ORDER BY likes DESC"
    cursor.execute(query, params)
    books = cursor.fetchall()
    db.close()
    return [dict(b) for b in books]

@router.get("/{book_id}")
def get_book(book_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("SELECT * FROM books WHERE id = ?", (book_id,))
    book = cursor.fetchone()
    db.close()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    return dict(book)

@router.post("/")
def add_book(book: BookCreate):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO books (title, author, category, description, file_url, language, publish_year, image_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (book.title, book.author, book.category, book.description,
          book.file_url, book.language, book.publish_year, book.image_url))
    db.commit()
    new_id = cursor.lastrowid
    db.close()
    return {"message": "Book added successfully", "book_id": new_id}

@router.post("/{book_id}/like")
def like_book(book_id: int):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("UPDATE books SET likes = likes + 1 WHERE id = ?", (book_id,))
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
    cursor.execute("DELETE FROM books WHERE id = ?", (book_id,))
    if cursor.rowcount == 0:
        db.close()
        raise HTTPException(status_code=404, detail="Book not found")
    db.commit()
    db.close()
    return {"message": "Book deleted successfully"}