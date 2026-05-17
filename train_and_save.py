# train_and_save.py
import pickle
from recommender import train_model
from database import get_db

db = get_db()
model, users, items, user_idx, item_idx, matrix = train_model(db)
db.close()

with open("model.pkl", "wb") as f:
    pickle.dump({
        "model": model,
        "users": users,
        "items": items,
        "user_idx": user_idx,
        "item_idx": item_idx,
        "matrix": matrix,
    }, f)

print("Model saved.")

