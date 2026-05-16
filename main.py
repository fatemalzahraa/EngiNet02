import pickle
from recommender import train_model


@app.get("/recommendations")
def get_recommendations(current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM users WHERE email = %s", (current_user["email"],))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_id = user["id"]

        model, users, items, user_idx, item_idx, matrix = train_model(db)
        if model is None:
            return get_popular_content(cursor)

        if user_id not in user_idx:
            return get_popular_content(cursor)

        u_idx = user_idx[user_id]
        user_vector = matrix[u_idx]

        result = model.recommend(u_idx, user_vector, N=30, filter_already_liked_items=True)
        if isinstance(result, tuple):
            recommended_ids, scores = result
        else:
            recommended_ids = result[:, 0].astype(int)
            scores = result[:, 1]

        predictions = [(items[i], float(scores[j])) for j, i in enumerate(recommended_ids)]
        predictions.sort(key=lambda x: x[1], reverse=True)

        courses, books, articles = [], [], []
        for item_id, score in predictions:
            content_type, content_id = item_id.split('_', 1)
            if content_type == 'course' and len(courses) < 10:
                courses.append(int(content_id))
            elif content_type == 'book' and len(books) < 10:
                books.append(int(content_id))
            elif content_type == 'article' and len(articles) < 10:
                articles.append(int(content_id))

        return {
            "courses": fetch_by_ids(cursor, "courses", courses),
            "books": fetch_by_ids(cursor, "books", books),
            "articles": fetch_by_ids(cursor, "articles", articles),
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


def fetch_by_ids(cursor, table, ids):
    if not ids:
        return []
    cursor.execute(f"SELECT * FROM {table} WHERE id = ANY(%s)", (ids,))
    return cursor.fetchall()


def get_popular_content(cursor):
    cursor.execute("SELECT * FROM courses ORDER BY COALESCE(rating,0) DESC LIMIT 10")
    courses = cursor.fetchall()
    cursor.execute("SELECT * FROM books ORDER BY COALESCE(likes,0) DESC LIMIT 10")
    books = cursor.fetchall()
    cursor.execute("SELECT * FROM articles ORDER BY COALESCE(rating,0) DESC LIMIT 10")
    articles = cursor.fetchall()
    return {"courses": courses, "books": books, "articles": articles}


@app.post("/interact")
def record_interaction(
    content_type: str,
    content_id: int,
    interaction_type: str,
    current_user: dict = Depends(get_current_user)
):
    scores = {"view": 1, "like": 3, "save": 4, "complete": 5}
    score = scores.get(interaction_type, 1)

    db = get_db()
    try:
        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT id, %s, %s, %s, %s FROM users WHERE email = %s
            ON CONFLICT DO NOTHING
        """, (content_type, content_id, interaction_type, score, current_user["email"]))
        db.commit()
    finally:
        db.close()
    return {"status": "recorded"}