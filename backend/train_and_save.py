# train_and_save.py
import pickle
import logging
from datetime import datetime, timezone
from recommender import train_model
from database import get_db

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ALS is a supporting signal at ~5% weight, so it only makes sense to train
# when there's enough interaction data. Below this threshold the sparse matrix
# produces noisy factors that hurt more than they help.
MIN_INTERACTIONS_FOR_ALS = 500   # total (user, item) pairs in the matrix
MIN_USERS_FOR_ALS        = 50
MIN_ITEMS_FOR_ALS        = 20

db = get_db()
try:
    result = train_model(db)
except Exception as exc:
    logger.error("train_model() failed — aborting: %s", exc)
    db.close()
    raise
finally:
    db.close()

model, users, items, user_idx, item_idx, matrix = result

# ── Threshold check ────────────────────────────────────────────────────────────
n_users        = len(users)
n_items        = len(items)
n_interactions = int(matrix.nnz) if hasattr(matrix, "nnz") else len(matrix.nonzero()[0])

skip_als = False
if n_interactions < MIN_INTERACTIONS_FOR_ALS:
    logger.warning(
        "Only %d interactions (need %d) — ALS model will be stored as None. "
        "The hybrid engine will rely on content-based + social + popular signals.",
        n_interactions, MIN_INTERACTIONS_FOR_ALS,
    )
    skip_als = True
elif n_users < MIN_USERS_FOR_ALS:
    logger.warning("Only %d users (need %d) — skipping ALS.", n_users, MIN_USERS_FOR_ALS)
    skip_als = True
elif n_items < MIN_ITEMS_FOR_ALS:
    logger.warning("Only %d items (need %d) — skipping ALS.", n_items, MIN_ITEMS_FOR_ALS)
    skip_als = True

if skip_als:
    model = None   # get_als_scores() in recommender.py already handles model=None gracefully

# ── Persist ────────────────────────────────────────────────────────────────────
payload = {
    "model":    model,
    "users":    users,
    "items":    items,
    "user_idx": user_idx,
    "item_idx": item_idx,
    "matrix":   matrix,
    # --- metadata (used by router for stale-model warnings and observability) ---
    "_meta": {
        "trained_at":     datetime.now(timezone.utc).isoformat(),
        "n_users":        n_users,
        "n_items":        n_items,
        "n_interactions": n_interactions,
        "als_trained":    model is not None,
    },
}

try:
    with open("model.pkl", "wb") as f:
        pickle.dump(payload, f)
except OSError as exc:
    logger.error("Could not write model.pkl: %s", exc)
    raise

logger.info(
    "Model saved — %d users, %d items, %d interactions, ALS trained: %s",
    n_users, n_items, n_interactions, model is not None,
)