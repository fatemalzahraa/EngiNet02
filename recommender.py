import numpy as np
from scipy.sparse import csr_matrix
from implicit import als

def train_model(db):
    try:
        cursor = db.cursor()
        cursor.execute("SELECT user_id, content_type, content_id, score FROM user_interactions")
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

        matrix = csr_matrix((data, (row_ids, col_ids)), shape=(n_users, n_items))
        print("Matrix shape:", matrix.shape)
        print("Users:", len(user_idx))
        print("Items:", len(item_idx))
       
        model = als.AlternatingLeastSquares(factors=50, iterations=20, use_gpu=False)
        model.fit(matrix.T)

        users = {v: k for k, v in user_idx.items()}
        items = {v: k for k, v in item_idx.items()}

        return model, users, items, user_idx, item_idx, matrix

    except Exception as e:
        print(f"train_model error: {e}")
        return None, None, None, None, None, None
