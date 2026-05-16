# recommender.py
import implicit
import numpy as np
from scipy.sparse import csr_matrix

def train_model(db):
    cursor = db.cursor()
    cursor.execute("""
        SELECT user_id, content_type || '_' || content_id::text as item_id, score
        FROM user_interactions
    """)
    interactions = cursor.fetchall()
    
    if len(interactions) < 10:
        return None, None, None

    # بناء matrix
    users = list({r["user_id"] for r in interactions})
    items = list({r["item_id"] for r in interactions})
    user_idx = {u: i for i, u in enumerate(users)}
    item_idx = {it: i for i, it in enumerate(items)}

    rows = [user_idx[r["user_id"]] for r in interactions]
    cols = [item_idx[r["item_id"]] for r in interactions]
    vals = [r["score"] for r in interactions]

    matrix = csr_matrix((vals, (rows, cols)), shape=(len(users), len(items)))

    model = implicit.als.AlternatingLeastSquares(factors=50, iterations=20)
    model.fit(matrix)

    return model, users, items, user_idx, item_idx, matrix