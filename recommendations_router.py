"""
recommendations_router.py
نظام توصيات هجين: ALS + Content-Based + Popular
"""

import os
import pickle
from fastapi import APIRouter, Depends, HTTPException
from database import get_db
from dependencies import get_current_user
from recommender import train_model, get_content_based, get_popular, get_als_recommendations
from sync_interactions import sync_interactions

router = APIRouter(prefix="/recommendations", tags=["Recommendations"])

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


def _enrich(db, table: str, ids: list[int]) -> list[dict]:
    if not ids:
        return []
    return db.table(table).select("id, title, image_url, rating, category").in_("id", ids).execute().data


def _get_search_based_books(db, user_id: int, limit: int = 5) -> list[dict]:
    try:
        searches = db.table("search_history").select("query").eq("user_id", user_id).order("created_at", desc=True).limit(5).execute().data
        keywords = [r["query"].strip() for r in searches if len((r["query"] or "").strip()) >= 2]
        if not keywords:
            return []

        # نجيب كتب تطابق أي keyword
        all_books = db.table("books").select("id, title, image_url, rating, category, author, description").execute().data
        matched = []
        seen_ids = set()
        for book in all_books:
            for kw in keywords:
                kw_lower = kw.lower()
                if any(kw_lower in str(book.get(f, "")).lower() for f in ["title", "author", "category", "description"]):
                    if book["id"] not in seen_ids:
                        matched.append(book)
                        seen_ids.add(book["id"])
                    break

        matched.sort(key=lambda x: (x.get("rating") or 0), reverse=True)
        return matched[:limit]
    except Exception as e:
        print(f"search_based_books error: {e}")
        return []


# ── GET /recommendations ────────────────────────────────────
@router.get("/")
def get_recommendations(limit: int = 5, current_user: dict = Depends(get_current_user)):
    db = get_db()

    # جلب user_id
    user_row = db.table("users").select("id").eq("email", current_user["email"]).single().execute().data
    if not user_row:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_row["id"]

    # عدد التفاعلات
    interaction_count = db.table("user_interactions").select("id", count="exact").eq("user_id", user_id).execute().count or 0

    # حالة 1: مستخدم جديد → Popular
    if interaction_count < 3:
        courses, books, articles = get_popular(db, limit)
        return {"strategy": "popular", "courses": courses, "books": books, "articles": articles}

    # حالة 2: Content-Based
    cb_courses, cb_books, cb_articles = get_content_based(db, user_id, limit)
    search_books = _get_search_based_books(db, user_id, limit)

    # حالة 3: ALS
    cached = _load_model()
    als_courses, als_books, als_articles = [], [], []

    if cached and cached.get("model"):
        als_c, als_b, als_a = get_als_recommendations(
            model=cached["model"], user_idx=cached["user_idx"],
            item_idx=cached["item_idx"], items_rev=cached["items"],
            matrix=cached["matrix"], user_id=user_id, limit=limit,
        )
        als_courses = _enrich(db, "courses", [x["id"] for x in als_c])
        als_books   = _enrich(db, "books",   [x["id"] for x in als_b])
        als_articles = _enrich(db, "articles", [x["id"] for x in als_a])

    def merge(a, b):
        seen = {x["id"] for x in a}
        return (list(a) + [x for x in b if x["id"] not in seen])[:limit]

    final_courses  = merge(als_courses, cb_courses)
    final_books    = merge(search_books, merge(als_books, cb_books))
    final_articles = merge(als_articles, cb_articles)

    # Fallback → Popular
    if not final_courses and not final_books and not final_articles:
        courses, books, articles = get_popular(db, limit)
        return {"strategy": "popular_fallback", "courses": courses, "books": books, "articles": articles}

    strategy = "hybrid_search" if search_books else ("hybrid" if cached and cached.get("model") else "content_based")
    return {"strategy": strategy, "courses": final_courses, "books": final_books, "articles": final_articles}


# ── POST /recommendations/train ────────────────────────────
@router.post("/train")
def train_recommendations(current_user: dict = Depends(get_current_user)):
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin only")

    total, users = sync_interactions()
    if total < 10:
        return {"message": "Not enough interactions to train", "total_interactions": total}

    db = get_db()
    model, users_rev, items_rev, user_idx, item_idx, matrix = train_model(db)
    if model is None:
        return {"message": "Training failed", "total_interactions": total}

    _save_model({"model": model, "users": users_rev, "items": items_rev,
                 "user_idx": user_idx, "item_idx": item_idx, "matrix": matrix})

    return {"message": "Model trained successfully", "total_interactions": total, "users": users}


# ── POST /recommendations/sync ─────────────────────────────
@router.post("/sync")
def sync_only(current_user: dict = Depends(get_current_user)):
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin only")
    total, users = sync_interactions()
    return {"message": "Interactions synced", "total_interactions": total, "users": users}