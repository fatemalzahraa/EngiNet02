from fastapi import APIRouter, HTTPException, Depends
from database import get_db
from pydantic import BaseModel
from typing import Optional
from dependencies import get_current_user, require_role, add_points

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
    try:
        cursor = db.cursor()
        query = "SELECT * FROM books WHERE 1=1"
        params = []
        if search:
            query += " AND (title ILIKE %s OR author ILIKE %s)"
            params.extend([f"%{search}%", f"%{search}%"])
        if category:
            query += " AND category ILIKE %s"
            params.append(f"%{category}%")
        query += " ORDER BY likes DESC"
        cursor.execute(query, params)
        return cursor.fetchall()
    finally:
        db.close()


@router.get("/{book_id}")
def get_book(book_id: int):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM books WHERE id = %s", (book_id,))
        book = cursor.fetchone()
        if not book:
            raise HTTPException(status_code=404, detail="Book not found")
        return book
    finally:
        db.close()


@router.post("/")
def add_book(book: BookCreate, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            """
            INSERT INTO books (title, author, category, description, file_url,
                               language, publish_year, image_url)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (
                book.title, book.author, book.category, book.description,
                book.file_url, book.language, book.publish_year, book.image_url,
            ),
        )
        new_id = cursor.fetchone()["id"]
        add_points(cursor, user["id"], 10)
        db.commit()
        return {"message": "Book added successfully", "book_id": new_id}
    finally:
        db.close()


@router.post("/{book_id}/like")
def like_book(book_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("SELECT id FROM books WHERE id = %s", (book_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Book not found")

        # Prevent duplicate likes
        cursor.execute(
            "SELECT 1 FROM book_likes WHERE book_id = %s AND user_id = %s",
            (book_id, user["id"]),
        )
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="You already liked this book")

        cursor.execute(
            "INSERT INTO book_likes (book_id, user_id) VALUES (%s, %s)",
            (book_id, user["id"]),
        )
        cursor.execute("UPDATE books SET likes = likes + 1 WHERE id = %s", (book_id,))
        db.commit()
        return {"message": "Book liked!"}
    finally:
        db.close()


@router.delete("/{book_id}/like")
def unlike_book(book_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            "DELETE FROM book_likes WHERE book_id = %s AND user_id = %s RETURNING 1",
            (book_id, user["id"]),
        )
        if not cursor.fetchone():
            raise HTTPException(status_code=400, detail="You haven't liked this book")

        cursor.execute(
            "UPDATE books SET likes = GREATEST(likes - 1, 0) WHERE id = %s", (book_id,)
        )
        db.commit()
        return {"message": "Book unliked!"}
    finally:
        db.close()


@router.delete("/{book_id}")
def delete_book(
    book_id: int,
    current_user: dict = Depends(require_role("admin", "engineer")),
):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM books WHERE id = %s", (book_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Book not found")
        cursor.execute("DELETE FROM book_likes WHERE book_id = %s", (book_id,))
        cursor.execute("DELETE FROM books WHERE id = %s", (book_id,))
        db.commit()
        return {"message": "Book deleted successfully"}
    finally:
        db.close()