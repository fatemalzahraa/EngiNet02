"""
recommendations_router.py
─────────────────────────────────────────────
Tüm öneri mantığı artık recommender.get_hybrid_recommendations() içinde.
Router sadece:
  • Kullanıcı kimliğini çözümler
  • Cold-start (< 3 etkileşim) → popular
  • Aksi hâlde hybrid engine'i çağırır
  • /train ve /sync admin endpoint'leri
"""

import os
import pickle
import logging
from fastapi import APIRouter, Depends, HTTPException
from database import get_db
from dependencies import get_current_user
from recommender import get_popular, get_hybrid_recommendations, train_model
from sync_interactions import sync_interactions

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/recommendations", tags=["Recommendations"])

_model_cache: dict | None = None
MODEL_PATH = "model.pkl"


# ── Model cache helpers ───────────────────────────────────────────

def _load_model() -> dict | None:
    global _model_cache
    if _model_cache is not None:
        return _model_cache
    if os.path.exists(MODEL_PATH):
        try:
            with open(MODEL_PATH, "rb") as f:
                _model_cache = pickle.load(f)
            meta = _model_cache.get("_meta", {})
            logger.info(
                "ALS model loaded — trained_at=%s, users=%s, items=%s, als_trained=%s",
                meta.get("trained_at", "?"),
                meta.get("n_users", "?"),
                meta.get("n_items", "?"),
                meta.get("als_trained", "?"),
            )
        except Exception as exc:
            logger.warning("Could not load model.pkl: %s", exc)
    return _model_cache


def _save_model(data: dict):
    global _model_cache
    _model_cache = data
    try:
        with open(MODEL_PATH, "wb") as f:
            pickle.dump(data, f)
    except OSError as exc:
        logger.warning("Could not save model.pkl: %s", exc)


# ── GET /recommendations ─────────────────────────────────────────

@router.get("/")
def get_recommendations(
    limit: int = 5,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()

    # ── Kullanıcı kimliği ────────────────────────────────────────
    user_row = (
        db.table("users")
        .select("id")
        .eq("email", current_user["email"])
        .single()
        .execute()
        .data
    )
    if not user_row:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user_row["id"]

    # ── Etkileşim sayısı (Cold-start kontrolü) ───────────────────
    interaction_count = (
        db.table("user_interactions")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .execute()
        .count
        or 0
    )

    # ── Cold Start ───────────────────────────────────────────────
    if interaction_count < 3:
        courses, books, articles = get_popular(db, limit)
        return {
            "strategy": "popular",
            "message": "Interact more to get personalised recommendations",
            "courses": courses,
            "books": books,
            "articles": articles,
        }

    # ── Hybrid Engine ────────────────────────────────────────────
    als_bundle = _load_model()  # None → ALS sinyali es geçilir, diğerleri çalışır

    courses, books, articles, debug = get_hybrid_recommendations(
        db=db,
        user_id=user_id,
        limit=limit,
        als_bundle=als_bundle,
    )

    # ── Fallback: hybrid tamamen boş döndüyse popular ────────────
    if not courses and not books and not articles:
        courses, books, articles = get_popular(db, limit)
        return {
            "strategy": "popular_fallback",
            "courses": courses,
            "books": books,
            "articles": articles,
        }

    return {
        "strategy": "hybrid",
        "signals_used": debug.get("signals_used", []),
        "courses": courses,
        "books": books,
        "articles": articles,
    }


# ── POST /recommendations/train ──────────────────────────────────

@router.post("/train")
def train_recommendations(current_user: dict = Depends(get_current_user)):
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin only")

    total, users = sync_interactions()
    if total < 10:
        return {
            "message": "Not enough interactions to train",
            "total_interactions": total,
        }

    db = get_db()
    result = train_model(db)
    model, users_rev, items_rev, user_idx, item_idx, matrix = result

    if model is None:
        return {"message": "Training failed or skipped (sparse data)", "total_interactions": total}

    _save_model({
        "model":    model,
        "users":    users_rev,
        "items":    items_rev,
        "user_idx": user_idx,
        "item_idx": item_idx,
        "matrix":   matrix,
    })

    return {
        "message": "Model trained and cached",
        "total_interactions": total,
        "users": users,
    }


# ── POST /recommendations/sync ───────────────────────────────────

@router.post("/sync")
def sync_only(current_user: dict = Depends(get_current_user)):
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin only")
    total, users = sync_interactions()
    return {
        "message": "Interactions synced",
        "total_interactions": total,
        "users": users,
    }