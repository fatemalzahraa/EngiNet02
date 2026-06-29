from fastapi import APIRouter, HTTPException, Depends
from database import get_db
from pydantic import BaseModel
from typing import Optional
from dependencies import get_current_user, require_role, add_points_supabase
from supabase import create_client
import os

router = APIRouter(prefix="/books", tags=["Books"])

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
supabase_admin = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


class BookCreate(BaseModel):
    title: str
    author: str
    category: str
    description: str
    file_url: str
    language: Optional[str] = "English"
    publish_year: Optional[int] = 2024
    image_url: Optional[str] = ""


class BookUpdate(BaseModel):
    title: Optional[str] = None
    author: Optional[str] = None
    category: Optional[str] = None
    description: Optional[str] = None
    file_url: Optional[str] = None
    language: Optional[str] = None
    publish_year: Optional[int] = None
    image_url: Optional[str] = None


@router.get("/")
def get_all_books(search: Optional[str] = None, category: Optional[str] = None):
    db = get_db()
    query = db.table("books").select("*")
    if search:
        query = query.ilike("title", f"%{search}%")
    if category:
        query = query.ilike("category", f"%{category}%")
    return query.order("likes", desc=True).execute().data


@router.get("/{book_id}")
def get_book(book_id: int, current_user: dict = Depends(get_current_user)):
    result = supabase_admin.table("books").select("*").eq("id", book_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Book not found")
    book = result.data[0]

    comments = supabase_admin.table("comments").select("id").eq("book_id", book_id).execute()
    book["comments_count"] = len(comments.data)

    likes = supabase_admin.table("likes").select("id").eq("book_id", book_id).execute()
    book["likes"] = len(likes.data)

    user_result = supabase_admin.table("users").select("id").eq("email", current_user["email"]).execute()
    if user_result.data:
        user_id = user_result.data[0]["id"]
        my_like = supabase_admin.table("likes").select("id").eq("user_id", user_id).eq("book_id", book_id).execute()
        book["is_liked"] = len(my_like.data) > 0
        my_bookmark = supabase_admin.table("bookmarks").select("id").eq("user_id", user_id).eq("book_id", book_id).execute()
        book["is_bookmarked"] = len(my_bookmark.data) > 0
        my_rating = supabase_admin.table("book_ratings").select("rating").eq("user_id", user_id).eq("book_id", book_id).execute()
        book["my_rating"] = my_rating.data[0]["rating"] if my_rating.data else 0
    else:
        book["is_liked"] = False
        book["is_bookmarked"] = False
        book["my_rating"] = 0

    return book


@router.get("/{book_id}/comments")
def get_book_comments(book_id: int):
    result = supabase_admin.table("comments").select("*").eq("book_id", book_id).order("created_at").execute()
    return result.data


@router.post("/")
def add_book(book: BookCreate, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    result = db.table("books").insert({
        "title": book.title,
        "author": book.author,
        "category": book.category,
        "description": book.description,
        "file_url": book.file_url,
        "language": book.language,
        "publish_year": book.publish_year,
        "image_url": book.image_url,
    }).execute()

    new_id = result.data[0]["id"]
    add_points_supabase(db, user_id, 10)
    return {"message": "Book added successfully", "book_id": new_id}


@router.post("/{book_id}/like")
def like_book(book_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    book_result = db.table("books").select("id, likes").eq("id", book_id).execute()
    if not book_result.data:
        raise HTTPException(status_code=404, detail="Book not found")

    existing = db.table("book_likes").select("id").eq("book_id", book_id).eq("user_id", user_id).execute()
    if existing.data:
        raise HTTPException(status_code=400, detail="You already liked this book")

    db.table("book_likes").insert({"book_id": book_id, "user_id": user_id}).execute()
    new_likes = (book_result.data[0]["likes"] or 0) + 1
    db.table("books").update({"likes": new_likes}).eq("id", book_id).execute()
    return {"message": "Book liked!"}


@router.delete("/{book_id}/like")
def unlike_book(book_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    existing = db.table("book_likes").select("id").eq("book_id", book_id).eq("user_id", user_id).execute()
    if not existing.data:
        raise HTTPException(status_code=400, detail="You haven't liked this book")

    db.table("book_likes").delete().eq("book_id", book_id).eq("user_id", user_id).execute()
    book_result = db.table("books").select("likes").eq("id", book_id).execute()
    new_likes = max((book_result.data[0]["likes"] or 1) - 1, 0)
    db.table("books").update({"likes": new_likes}).eq("id", book_id).execute()
    return {"message": "Book unliked!"}


@router.put("/{book_id}")
def update_book(
    book_id: int,
    book: BookUpdate,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    user_result = db.table("users").select("id, username, role").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    existing = db.table("books").select("id, author_username").eq("id", book_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Book not found")

    if existing.data[0].get("author_username") != user["username"] and user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Not allowed to edit this book")

    update_data = {k: v for k, v in book.dict(exclude_unset=True).items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    db.table("books").update(update_data).eq("id", book_id).execute()
    return {"message": "Book updated successfully"}


@router.delete("/{book_id}")
def delete_book(book_id: int, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user_result = db.table("users").select("id, username, role").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    book_result = db.table("books").select("id, author_username").eq("id", book_id).execute()
    if not book_result.data:
        raise HTTPException(status_code=404, detail="Book not found")
    book = book_result.data[0]

    if book.get("author_username") != user["username"] and user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Not allowed")

    db.table("book_likes").delete().eq("book_id", book_id).execute()
    db.table("books").delete().eq("id", book_id).execute()
    return {"message": "Book deleted successfully"}