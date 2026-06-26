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
    print("GET_RECOMMENDATIONS CALLED")
    db = get_db()

    
        # ── DEBUG SUPABASE CONNECTION ───────────────────────────────
    print("=" * 60)
    print("SUPABASE_URL =", os.getenv("SUPABASE_URL"))
    print("SUPABASE_KEY prefix =", os.getenv("SUPABASE_KEY", "")[:20])

    try:
        test = (
            db.table("user_interactions")
            .select("*")
            .limit(3)
            .execute()
        )
        print("TOTAL SAMPLE ROWS =", len(test.data))
        print("SAMPLE =", test.data)
    except Exception as e:
        print("SUPABASE ERROR =", e)

    print("=" * 60)
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
    result = (
        db.table("user_interactions")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )

    print("=" * 50)
    print("USER_ID =", user_id)
    print("ROWS FOUND =", len(result.data))
    print("DATA =", result.data[:5] if result.data else [])
    print("=" * 50)

    interaction_count = len(result.data)

    print("=" * 50)
    print(f"USER_ID = {user_id}")
    print(f"INTERACTION_COUNT = {interaction_count}")
    print("=" * 50)

    # ── Cold Start ───────────────────────────────────────────────
    if interaction_count < 3:
        print("COLD START - returning popular")
        courses, books, articles = get_popular(db, limit)
        return {
            "strategy": "popular",
            "message": "Interact more to get personalised recommendations",
            "courses": courses,
            "books": books,
            "articles": articles,
        }

    # ── Hybrid Engine ────────────────────────────────────────────
    print("HYBRID ENGINE STARTED")

    als_bundle = _load_model()

    courses, books, articles, debug = get_hybrid_recommendations(
        db=db,
        user_id=user_id,
        limit=limit,
        als_bundle=als_bundle,
    )

    print("SIGNALS =", debug.get("signals_used"))
    print("COURSES =", len(courses))
    print("BOOKS =", len(books))
    print("ARTICLES =", len(articles))

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
    
    # train_model'den dönen değerleri doğru şekilde al
    if len(result) == 5:
        model, users_rev, items_rev, user_idx, item_idx = result
        matrix = None
    elif len(result) == 6:
        model, users_rev, items_rev, user_idx, item_idx, matrix = result
    else:
        return {"message": "Training failed: unexpected return format", "total_interactions": total}

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