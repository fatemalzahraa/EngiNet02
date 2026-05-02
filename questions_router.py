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


@router.get("")
def get_questions():
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            SELECT q.*, u.username, u.profile_image,
              COALESCE((SELECT COUNT(*) FROM answers a WHERE a.question_id = q.id), 0) AS answers_count
            FROM questions q
            LEFT JOIN users u ON u.id = q.user_id
            ORDER BY q.created_at DESC
        """)
        return cursor.fetchall()
    finally:
        db.close()


@router.post("")
async def add_question(
    title: str = Form(...),
    content: str = Form(...),
    category: str = Form(""),
    media: Optional[UploadFile] = File(None),
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()

        cursor.execute(
            "SELECT id, username, profile_image FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

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

        cursor.execute(
            """
            INSERT INTO questions (
              user_id, title, content, category, media_url, media_type, likes
            )
            VALUES (%s,%s,%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (
                user["id"],
                title,
                content,
                category,
                media_url,
                media_type,
                0,
            ),
        )

        question_id = cursor.fetchone()["id"]
        db.commit()

        return {"message": "Question added", "question_id": question_id}

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/{question_id}/answers")
def get_answers(question_id: int):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            SELECT a.*, u.username, u.profile_image
            FROM answers a
            LEFT JOIN users u ON u.id = a.user_id
            WHERE a.question_id = %s
            ORDER BY a.created_at ASC
        """, (question_id,))
        return cursor.fetchall()
    finally:
        db.close()


@router.post("/{question_id}/answers")
def add_answer(
    question_id: int,
    answer: AnswerCreate,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()

        cursor.execute(
            "SELECT id, username, profile_image FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("SELECT user_id FROM questions WHERE id = %s", (question_id,))
        question = cursor.fetchone()

        if not question:
            raise HTTPException(status_code=404, detail="Question not found")

        cursor.execute(
            """
            INSERT INTO answers (question_id, user_id, content)
            VALUES (%s,%s,%s)
            RETURNING id
            """,
            (question_id, user["id"], answer.content),
        )

        answer_id = cursor.fetchone()["id"]

        if question["user_id"] != user["id"]:
            cursor.execute(
                """
                INSERT INTO notifications (user_id, message, is_read, question_id)
                VALUES (%s,%s,%s,%s)
                """,
                (
                    question["user_id"],
                    f"{user['username']} answered your question.",
                    0,
                    question_id,
                ),
            )

        db.commit()
        return {"message": "Answer added", "answer_id": answer_id}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/{question_id}/like")
def like_question(
    question_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()

        cursor.execute(
            "SELECT id, username FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute("SELECT user_id FROM questions WHERE id = %s", (question_id,))
        question = cursor.fetchone()

        if not question:
            raise HTTPException(status_code=404, detail="Question not found")

        cursor.execute(
            """
            SELECT id FROM question_likes
            WHERE user_id = %s AND question_id = %s
            """,
            (user["id"], question_id),
        )
        existing_like = cursor.fetchone()

        if existing_like:
            cursor.execute(
                """
                DELETE FROM question_likes
                WHERE user_id = %s AND question_id = %s
                """,
                (user["id"], question_id),
            )
            cursor.execute(
                """
                UPDATE questions
                SET likes = GREATEST(COALESCE(likes, 0) - 1, 0)
                WHERE id = %s
                """,
                (question_id,),
            )
            db.commit()
            return {"message": "Question unliked", "liked": False}

        cursor.execute(
            """
            INSERT INTO question_likes (user_id, question_id)
            VALUES (%s,%s)
            """,
            (user["id"], question_id),
        )

        cursor.execute(
            """
            UPDATE questions
            SET likes = COALESCE(likes, 0) + 1
            WHERE id = %s
            """,
            (question_id,),
        )

        if question["user_id"] != user["id"]:
            cursor.execute(
                """
                INSERT INTO notifications (user_id, message, is_read, question_id)
                VALUES (%s,%s,%s,%s)
                """,
                (
                    question["user_id"],
                    f"{user['username']} liked your question.",
                    0,
                    question_id,
                ),
            )

        db.commit()
        return {"message": "Question liked", "liked": True}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()

@router.post("/{question_id}/save")
def save_question(
    question_id: int,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()

        cursor.execute(
            "SELECT id FROM users WHERE email = %s",
            (current_user["email"],),
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        cursor.execute(
            """
            INSERT INTO saved_questions (user_id, question_id)
            VALUES (%s,%s)
            ON CONFLICT (user_id, question_id) DO NOTHING
            """,
            (user["id"], question_id),
        )

        db.commit()
        return {"message": "Question saved"}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()