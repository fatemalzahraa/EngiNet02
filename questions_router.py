from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form
from typing import Optional
from pydantic import BaseModel
from database import get_db
from dependencies import get_current_user
from supabase import create_client
import os
import time

router = APIRouter(prefix="/questions", tags=["Questions"])

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase_admin = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


class AnswerCreate(BaseModel):
    content: str
    parent_answer_id: int | None = None


@router.get("")
def get_questions(current_user: dict = Depends(get_current_user)):
    db = get_db()

    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    user_id = user_result.data[0]["id"] if user_result.data else 0

    questions = db.table("questions").select(
        "*, users(username, profile_image)"
    ).order("created_at", desc=True).execute().data

    for q in questions:
        answers_count = db.table("answers").select("id", count="exact").eq("question_id", q["id"]).execute().count or 0
        q["answers_count"] = answers_count

        liked = db.table("question_likes").select("id").eq("question_id", q["id"]).eq("user_id", user_id).execute().data
        q["is_liked"] = len(liked) > 0

        saved = db.table("saved_questions").select("id").eq("question_id", q["id"]).eq("user_id", user_id).execute().data
        q["is_saved"] = len(saved) > 0

        # Flatten user join
        if q.get("users"):
            q["username"] = q["users"].get("username")
            q["profile_image"] = q["users"].get("profile_image")
            del q["users"]

    return questions


@router.post("")
async def add_question(
    title: str = Form(...),
    content: str = Form(...),
    category: str = Form(""),
    media: Optional[UploadFile] = File(None),
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id, username, profile_image").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    media_url = ""
    media_type = ""

    if media is not None:
        content_type = media.content_type or ""
        file_bytes = await media.read()
        safe_name = media.filename.replace(" ", "_")
        file_path = f"{user['id']}/{int(time.time() * 1000)}_{safe_name}"

        if content_type.startswith("image/"):
            bucket = "question-images"
            media_type = "image"
        elif content_type.startswith("video/"):
            bucket = "question-videos"
            media_type = "video"
        else:
            raise HTTPException(status_code=400, detail="Only image or video allowed")

        supabase_admin.storage.from_(bucket).upload(
            file_path,
            file_bytes,
            {"content-type": content_type},
        )
        media_url = supabase_admin.storage.from_(bucket).get_public_url(file_path)

    result = db.table("questions").insert({
        "user_id": user["id"],
        "title": title,
        "content": content,
        "category": category,
        "media_url": media_url,
        "media_type": media_type,
        "likes": 0,
    }).execute()

    question_id = result.data[0]["id"]
    return {"message": "Question added", "question_id": question_id}


@router.get("/mine")
def get_my_questions(current_user: dict = Depends(get_current_user)):
    db = get_db()

    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    questions = db.table("questions").select(
        "*, users(username, profile_image)"
    ).eq("user_id", user_id).order("created_at", desc=True).execute().data

    for q in questions:
        answers_count = db.table("answers").select("id", count="exact").eq("question_id", q["id"]).execute().count or 0
        q["answers_count"] = answers_count

        liked = db.table("question_likes").select("id").eq("question_id", q["id"]).eq("user_id", user_id).execute().data
        q["is_liked"] = len(liked) > 0

        saved = db.table("saved_questions").select("id").eq("question_id", q["id"]).eq("user_id", user_id).execute().data
        q["is_saved"] = len(saved) > 0

        if q.get("users"):
            q["username"] = q["users"].get("username")
            q["profile_image"] = q["users"].get("profile_image")
            del q["users"]

    return questions


@router.delete("/{question_id}")
def delete_question(
    question_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    question_result = db.table("questions").select("user_id").eq("id", question_id).execute()
    if not question_result.data:
        raise HTTPException(status_code=404, detail="Question not found")

    if question_result.data[0]["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not allowed")

    db.table("questions").delete().eq("id", question_id).execute()
    return {"message": "Question deleted"}


@router.get("/{question_id}/answers")
def get_answers(question_id: int):
    db = get_db()

    answers = db.table("answers").select(
        "*, users(username, profile_image)"
    ).eq("question_id", question_id).order("created_at").execute().data

    for a in answers:
        if a.get("users"):
            a["username"] = a["users"].get("username")
            a["profile_image"] = a["users"].get("profile_image")
            del a["users"]

    return answers


@router.post("/{question_id}/answers")
def add_answer(
    question_id: int,
    answer: AnswerCreate,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id, username, profile_image").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    question_result = db.table("questions").select("user_id").eq("id", question_id).execute()
    if not question_result.data:
        raise HTTPException(status_code=404, detail="Question not found")
    question = question_result.data[0]

    result = db.table("answers").insert({
        "question_id": question_id,
        "user_id": user["id"],
        "content": answer.content,
        "parent_answer_id": answer.parent_answer_id,
    }).execute()

    answer_id = result.data[0]["id"]

    if question["user_id"] != user["id"]:
        db.table("notifications").insert({
            "user_id": question["user_id"],
            "message": f"{user['username']} answered your question.",
            "is_read": False,
            "question_id": question_id,
        }).execute()

    return {"message": "Answer added", "answer_id": answer_id}


@router.post("/{question_id}/like")
def toggle_question_like(
    question_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id, username").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user = user_result.data[0]

    question_result = db.table("questions").select("id, user_id, likes").eq("id", question_id).execute()
    if not question_result.data:
        raise HTTPException(status_code=404, detail="Question not found")
    question = question_result.data[0]

    existing = db.table("question_likes").select("id").eq("user_id", user["id"]).eq("question_id", question_id).execute().data

    if existing:
        db.table("question_likes").delete().eq("user_id", user["id"]).eq("question_id", question_id).execute()
        new_likes = max((question["likes"] or 0) - 1, 0)
        db.table("questions").update({"likes": new_likes}).eq("id", question_id).execute()
        return {"liked": False, "likes": new_likes}

    db.table("question_likes").insert({"user_id": user["id"], "question_id": question_id}).execute()
    new_likes = (question["likes"] or 0) + 1
    db.table("questions").update({"likes": new_likes}).eq("id", question_id).execute()

    if question["user_id"] != user["id"]:
        db.table("notifications").insert({
            "user_id": question["user_id"],
            "message": f"{user['username']} liked your question.",
            "is_read": False,
            "question_id": question_id,
        }).execute()

    return {"liked": True, "likes": new_likes}


@router.post("/{question_id}/save")
def save_question(
    question_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    existing = db.table("saved_questions").select("id").eq("user_id", user_id).eq("question_id", question_id).execute().data
    if not existing:
        db.table("saved_questions").insert({"user_id": user_id, "question_id": question_id}).execute()

    return {"message": "Question saved"}


@router.put("/answers/{answer_id}")
def update_answer(
    answer_id: int,
    answer: AnswerCreate,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    existing = db.table("answers").select("user_id").eq("id", answer_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Answer not found")
    if existing.data[0]["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not allowed")

    db.table("answers").update({"content": answer.content}).eq("id", answer_id).execute()
    return {"message": "Answer updated"}


@router.delete("/answers/{answer_id}")
def delete_answer(
    answer_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    user_result = db.table("users").select("id").eq("email", current_user["email"]).execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_result.data[0]["id"]

    answer_result = db.table("answers").select("user_id").eq("id", answer_id).execute()
    if not answer_result.data:
        raise HTTPException(status_code=404, detail="Answer not found")
    if answer_result.data[0]["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not allowed")

    db.table("answers").delete().eq("id", answer_id).execute()
    return {"message": "Answer deleted"}