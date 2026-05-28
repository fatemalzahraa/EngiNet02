"""
recommendations_router.py
نظام توصيات هجين: ALS + Content-Based + Popular
"""

import os
import pickle
from fastapi import APIRouter, Depends, HTTPException
from database import get_db
from dependencies import get_current_user
from recommender import (
    train_model,
    get_content_based,
    get_popular,
    get_als_recommendations,
)
from sync_interactions import sync_interactions

router = APIRouter(prefix="/recommendations", tags=["Recommendations"])

# ── تحميل الموديل عند بدء التشغيل ──────────────────────────
_model_cache = None

MODEL_PATH = "model.pkl"


def _load_model():
    global _model_cache
    if _model_cache is not None:
        return _model_cache

    if os.path.exists(MODEL_PATH):
        try:
            with open(MODEL_PATH, "rb") as f:
                _model_cache = pickle.load(f)
            print("✅ Loaded ALS model from cache")
            return _model_cache
        except Exception as e:
            print(f"⚠️  Failed to load cached model: {e}")

    return None


def _save_model(data: dict):
    global _model_cache
    _model_cache = data
    try:
        with open(MODEL_PATH, "wb") as f:
            pickle.dump(data, f)
    except Exception as e:
        print(f"⚠️  Failed to save model: {e}")


def _enrich_courses(cursor, ids: list[int]) -> list[dict]:
    if not ids:
        return []
    placeholders = ",".join(["%s"] * len(ids))
    cursor.execute(
        f"SELECT id, title, image_url, rating, category FROM courses WHERE id IN ({placeholders})",
        ids,
    )
    return [dict(r) for r in cursor.fetchall()]


def _enrich_books(cursor, ids: list[int]) -> list[dict]:
    if not ids:
        return []
    placeholders = ",".join(["%s"] * len(ids))
    cursor.execute(
        f"SELECT id, title, image_url, rating, category FROM books WHERE id IN ({placeholders})",
        ids,
    )
    return [dict(r) for r in cursor.fetchall()]


def _enrich_articles(cursor, ids: list[int]) -> list[dict]:
    if not ids:
        return []
    placeholders = ",".join(["%s"] * len(ids))
    cursor.execute(
        f"SELECT id, title, image_url, rating, category FROM articles WHERE id IN ({placeholders})",
        ids,
    )
    return [dict(r) for r in cursor.fetchall()]


# ── GET /recommendations ────────────────────────────────────
@router.get("/")
def get_recommendations(
    limit: int = 5,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        cursor = db.cursor()

        # جلب user_id
        cursor.execute(
            "SELECT id FROM users WHERE email = %s", (current_user["email"],)
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_id = user["id"]

        # ── هل عنده تفاعلات؟ ──────────────────────────────
        cursor.execute(
            "SELECT COUNT(*) AS cnt FROM user_interactions WHERE user_id = %s",
            (user_id,),
        )
        interaction_count = cursor.fetchone()["cnt"]

        # ── حالة 1: مستخدم جديد → Popular ─────────────────
        if interaction_count < 3:
            courses, books, articles = get_popular(db, limit)
            return {
                "strategy": "popular",
                "courses": courses,
                "books": books,
                "articles": articles,
            }

        # ── حالة 2: Content-Based ───────────────────────────
        cb_courses, cb_books, cb_articles = get_content_based(db, user_id, limit)

        # ── حالة 3: ALS إذا الموديل محمّل ──────────────────
        cached = _load_model()
        als_courses, als_books, als_articles = [], [], []

        if cached and cached.get("model"):
            als_c, als_b, als_a = get_als_recommendations(
                model=cached["model"],
                user_idx=cached["user_idx"],
                item_idx=cached["item_idx"],
                items_rev=cached["items"],
                matrix=cached["matrix"],
                user_id=user_id,
                limit=limit,
            )
            als_course_ids = [x["id"] for x in als_c]
            als_book_ids = [x["id"] for x in als_b]
            als_article_ids = [x["id"] for x in als_a]

            als_courses = _enrich_courses(cursor, als_course_ids)
            als_books = _enrich_books(cursor, als_book_ids)
            als_articles = _enrich_articles(cursor, als_article_ids)

        # ── دمج النتائج (ALS أولاً ثم Content-Based) ───────
        def merge(als_list, cb_list):
            seen_ids = {x["id"] for x in als_list}
            merged = list(als_list)
            for item in cb_list:
                if item["id"] not in seen_ids:
                    merged.append(item)
            return merged[:limit]

        final_courses = merge(als_courses, cb_courses)
        final_books = merge(als_books, cb_books)
        final_articles = merge(als_articles, cb_articles)

        # ── إذا النتائج فاضية → Popular ─────────────────────
        if not final_courses and not final_books and not final_articles:
            courses, books, articles = get_popular(db, limit)
            return {
                "strategy": "popular_fallback",
                "courses": courses,
                "books": books,
                "articles": articles,
            }

        strategy = "hybrid" if cached and cached.get("model") else "content_based"

        return {
            "strategy": strategy,
            "courses": final_courses,
            "books": final_books,
            "articles": final_articles,
        }

    finally:
        db.close()


# ── POST /recommendations/train ────────────────────────────
@router.post("/train")
def train_recommendations(current_user: dict = Depends(get_current_user)):
    """
    يزامن التفاعلات ويدرب موديل ALS
    يُستدعى من الأدمن أو بـ cron job
    """
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin only")

    db = get_db()
    try:
        # 1. مزامنة التفاعلات
        total, users = sync_interactions()

        # 2. تدريب الموديل
        if total < 10:
            return {
                "message": "Not enough interactions to train",
                "total_interactions": total,
                "users": users,
            }

        model, users_rev, items_rev, user_idx, item_idx, matrix = train_model(db)

        if model is None:
            return {"message": "Training failed", "total_interactions": total}

        # 3. حفظ الموديل
        _save_model(
            {
                "model": model,
                "users": users_rev,
                "items": items_rev,
                "user_idx": user_idx,
                "item_idx": item_idx,
                "matrix": matrix,
            }
        )

        return {
            "message": "Model trained successfully",
            "total_interactions": total,
            "users": users,
            "strategy": "als",
        }

    finally:
        db.close()


# ── POST /recommendations/sync ─────────────────────────────
@router.post("/sync")
def sync_only(current_user: dict = Depends(get_current_user)):
    """مزامنة التفاعلات فقط بدون تدريب"""
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin only")

    db = get_db()
    try:
        total, users = sync_interactions()
        return {
            "message": "Interactions synced",
            "total_interactions": total,
            "users": users,
        }
    finally:
        db.close()