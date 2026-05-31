"""
recommender.py - نظام توصيات هجين
1. Collaborative Filtering (ALS)
2. Content-Based Filtering
3. Popular Items (Cold Start)
"""

import numpy as np
from scipy.sparse import csr_matrix


# ──────────────────────────────────────────────
# ALS Training
# ──────────────────────────────────────────────

def train_model(db):
    try:
        from implicit import als

        rows = db.table("user_interactions").select("user_id, content_type, content_id, score").execute().data

        if not rows:
            return None, None, None, None, None, None

        user_idx, item_idx = {}, {}
        data, row_ids, col_ids = [], [], []

        for r in rows:
            user_id = r["user_id"]
            item_id = f"{r['content_type']}_{r['content_id']}"

            if user_id not in user_idx:
                user_idx[user_id] = len(user_idx)
            if item_id not in item_idx:
                item_idx[item_id] = len(item_idx)

            data.append(float(r["score"]))
            row_ids.append(user_idx[user_id])
            col_ids.append(item_idx[item_id])

        matrix = csr_matrix(
            (data, (row_ids, col_ids)),
            shape=(len(user_idx), len(item_idx))
        )

        model = als.AlternatingLeastSquares(factors=50, iterations=20, use_gpu=False)
        model.fit(matrix)

        users_rev = {v: k for k, v in user_idx.items()}
        items_rev = {v: k for k, v in item_idx.items()}

        return model, users_rev, items_rev, user_idx, item_idx, matrix

    except Exception as e:
        print(f"train_model error: {e}")
        return None, None, None, None, None, None


# ──────────────────────────────────────────────
# Content-Based Filtering
# ──────────────────────────────────────────────

def get_content_based(db, user_id: int, limit: int = 5):
    # جلب التفاعلات السابقة
    interactions = db.table("user_interactions").select("content_type, content_id").eq("user_id", user_id).execute().data
    seen = {(r["content_type"], r["content_id"]) for r in interactions}

    content_ids = {"course": [], "book": [], "article": []}
    for r in interactions:
        content_ids[r["content_type"]].append(r["content_id"])

    # جلب الكاتيغوريات
    categories = set()

    if content_ids["course"]:
        rows = db.table("courses").select("category").in_("id", content_ids["course"]).execute().data
        categories.update(r["category"] for r in rows if r.get("category"))

    if content_ids["book"]:
        rows = db.table("books").select("category").in_("id", content_ids["book"]).execute().data
        categories.update(r["category"] for r in rows if r.get("category"))

    if content_ids["article"]:
        rows = db.table("articles").select("category").in_("id", content_ids["article"]).execute().data
        categories.update(r["category"] for r in rows if r.get("category"))

    if not categories:
        return [], [], []

    cat_list = list(categories)

    courses = [
        r for r in db.table("courses").select("id, title, image_url, rating, category")
        .in_("category", cat_list).order("rating", desc=True).limit(limit * 2).execute().data
        if ("course", r["id"]) not in seen
    ][:limit]

    books = [
        r for r in db.table("books").select("id, title, image_url, rating, category")
        .in_("category", cat_list).order("rating", desc=True).limit(limit * 2).execute().data
        if ("book", r["id"]) not in seen
    ][:limit]

    articles = [
        r for r in db.table("articles").select("id, title, image_url, rating, category")
        .in_("category", cat_list).order("rating", desc=True).limit(limit * 2).execute().data
        if ("article", r["id"]) not in seen
    ][:limit]

    return courses, books, articles


# ──────────────────────────────────────────────
# Popular / Trending (Cold Start)
# ──────────────────────────────────────────────

def get_popular(db, limit: int = 5):
    courses = db.table("courses").select("id, title, image_url, rating, category").order("rating", desc=True).limit(limit).execute().data
    books = db.table("books").select("id, title, image_url, rating, category").order("likes", desc=True).limit(limit).execute().data
    articles = db.table("articles").select("id, title, image_url, rating, category").order("rating", desc=True).limit(limit).execute().data
    return courses, books, articles


# ──────────────────────────────────────────────
# ALS Recommendations
# ──────────────────────────────────────────────

def get_als_recommendations(model, user_idx, item_idx, items_rev, matrix, user_id: int, limit: int = 10):
    try:
        if model is None or user_id not in user_idx:
            return [], [], []

        idx = user_idx[user_id]
        recommended_ids, _ = model.recommend(idx, matrix[idx], N=limit, filter_already_liked_items=True)

        courses, books, articles = [], [], []
        for item_idx_val in recommended_ids:
            item_key = items_rev.get(item_idx_val, "")
            if "_" not in item_key:
                continue
            content_type, content_id = item_key.split("_", 1)
            entry = {"id": int(content_id), "type": content_type}
            if content_type == "course":
                courses.append(entry)
            elif content_type == "book":
                books.append(entry)
            elif content_type == "article":
                articles.append(entry)

        return courses, books, articles

    except Exception as e:
        print(f"ALS recommend error: {e}")
        return [], [], []