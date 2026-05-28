"""
recommender.py - نظام توصيات هجين
يجمع بين:
1. Collaborative Filtering (ALS) - عندما يوجد بيانات كافية
2. Content-Based Filtering - يعتمد على الكاتيغوري والتقييم
3. Popular Items - للمستخدمين الجدد (Cold Start)
"""

import numpy as np
from scipy.sparse import csr_matrix

# ──────────────────────────────────────────────
# ALS Training
# ──────────────────────────────────────────────

def train_model(db):
    """تدريب نموذج ALS من user_interactions"""
    try:
        from implicit import als

        cursor = db.cursor()
        cursor.execute(
            "SELECT user_id, content_type, content_id, score FROM user_interactions"
        )
        rows = cursor.fetchall()

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

        n_users = len(user_idx)
        n_items = len(item_idx)

        matrix = csr_matrix(
            (data, (row_ids, col_ids)), shape=(n_users, n_items)
        )

        model = als.AlternatingLeastSquares(
            factors=50, iterations=20, use_gpu=False
        )
        model.fit(matrix)

        users_rev = {v: k for k, v in user_idx.items()}
        items_rev = {v: k for k, v in item_idx.items()}

        return model, users_rev, items_rev, user_idx, item_idx, matrix

    except Exception as e:
        print(f"train_model error: {e}")
        return None, None, None, None, None, None


# ──────────────────────────────────────────────
# Content-Based Recommendations
# ──────────────────────────────────────────────

def get_content_based(db, user_id: int, limit: int = 5):
    """
    يوصي بناءً على:
    - الكاتيغوريات التي تفاعل معها المستخدم
    - المحتوى ذي التقييم العالي في نفس الكاتيغوريات
    """
    cursor = db.cursor()

    # ── الكاتيغوريات التي يهتم بها المستخدم ──
    cursor.execute("""
        SELECT DISTINCT
            CASE ui.content_type
                WHEN 'course'  THEN c.category
                WHEN 'book'    THEN b.category
                WHEN 'article' THEN a.category
            END AS category
        FROM user_interactions ui
        LEFT JOIN courses  c ON ui.content_type = 'course'  AND ui.content_id = c.id
        LEFT JOIN books    b ON ui.content_type = 'book'    AND ui.content_id = b.id
        LEFT JOIN articles a ON ui.content_type = 'article' AND ui.content_id = a.id
        WHERE ui.user_id = %s
          AND (c.category IS NOT NULL OR b.category IS NOT NULL OR a.category IS NOT NULL)
    """, (user_id,))

    categories = [r["category"] for r in cursor.fetchall() if r["category"]]

    # ── المحتوى الذي تفاعل معه المستخدم مسبقاً ──
    cursor.execute(
        "SELECT content_type, content_id FROM user_interactions WHERE user_id = %s",
        (user_id,)
    )
    seen = {(r["content_type"], r["content_id"]) for r in cursor.fetchall()}

    courses, books, articles = [], [], []

    if categories:
        placeholders = ",".join(["%s"] * len(categories))

        # كورسات مقترحة
        cursor.execute(f"""
            SELECT id, title, image_url, rating, category, 'course' AS type
            FROM courses
            WHERE category IN ({placeholders})
            ORDER BY rating DESC NULLS LAST
            LIMIT %s
        """, (*categories, limit * 2))
        courses = [
            dict(r) for r in cursor.fetchall()
            if ("course", r["id"]) not in seen
        ][:limit]

        # كتب مقترحة
        cursor.execute(f"""
            SELECT id, title, image_url, rating, category, 'book' AS type
            FROM books
            WHERE category IN ({placeholders})
            ORDER BY rating DESC NULLS LAST, likes DESC NULLS LAST
            LIMIT %s
        """, (*categories, limit * 2))
        books = [
            dict(r) for r in cursor.fetchall()
            if ("book", r["id"]) not in seen
        ][:limit]

        # مقالات مقترحة
        cursor.execute(f"""
            SELECT id, title, image_url, rating, category, 'article' AS type
            FROM articles
            WHERE category IN ({placeholders})
            ORDER BY rating DESC NULLS LAST
            LIMIT %s
        """, (*categories, limit * 2))
        articles = [
            dict(r) for r in cursor.fetchall()
            if ("article", r["id"]) not in seen
        ][:limit]

    return courses, books, articles


# ──────────────────────────────────────────────
# Popular / Trending (Cold Start)
# ──────────────────────────────────────────────

def get_popular(db, limit: int = 5):
    """أكثر المحتوى تفاعلاً - للمستخدمين الجدد"""
    cursor = db.cursor()

    cursor.execute("""
        SELECT id, title, image_url, rating, category
        FROM courses
        ORDER BY rating DESC NULLS LAST, likes DESC NULLS LAST
        LIMIT %s
    """, (limit,))
    courses = [dict(r) for r in cursor.fetchall()]

    cursor.execute("""
        SELECT id, title, image_url, rating, category
        FROM books
        ORDER BY rating DESC NULLS LAST, likes DESC NULLS LAST
        LIMIT %s
    """, (limit,))
    books = [dict(r) for r in cursor.fetchall()]

    cursor.execute("""
        SELECT id, title, image_url, rating, category
        FROM articles
        ORDER BY rating DESC NULLS LAST
        LIMIT %s
    """, (limit,))
    articles = [dict(r) for r in cursor.fetchall()]

    return courses, books, articles


# ──────────────────────────────────────────────
# ALS Recommendations
# ──────────────────────────────────────────────

def get_als_recommendations(
    model, user_idx, item_idx, items_rev, matrix, user_id: int, limit: int = 10
):
    """توصيات ALS للمستخدم"""
    try:
        if model is None or user_id not in user_idx:
            return [], [], []

        idx = user_idx[user_id]
        recommended_ids, _ = model.recommend(
            idx, matrix[idx], N=limit, filter_already_liked_items=True
        )

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