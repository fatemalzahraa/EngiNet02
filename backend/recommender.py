"""
recommender.py - نظام توصيات شخصي هجين (Hybrid Recommender)
──────────────────────────────────────────────────────────
معماري للمنصات ذات قاعدة مستخدمين صغيرة (< 100). الـ Collaborative
Filtering الكلاسيكي (ALS / User-Based) لا يعمل بشكل موثوق مع بيانات
قليلة جداً (sparse + cold)، لذلك العمود الفقري هنا هو:

    1) Content-Based (TF-IDF على title + description + category)
       → "هذا يشبه ما تفاعلت معه" (مثل Netflix "More Like This")
    2) ملف المستخدم السلوكي (Behavioral Profile)
       → تفاعلات (view/like/save/complete) + تقييمات + bookmarks
         تُحوَّل إلى توزيع أوزان على الفئات والمؤلفين
    3) Social Proof (follows)
       → ما يحبه من تتابعهم يرفع ترتيب المحتوى
    4) Search-Based
       → سجل البحث الأخير كإشارة نية صريحة
    5) ALS — إن وُجد نموذج مدرّب — بوزن منخفض/متصاعد حسب حجم البيانات
    6) Popular/Trending — Cold Start (< 3 تفاعلات)

الدمج: normalize كل مصدر إشارة إلى [0, 1] ثم weighted sum ثابت
الأوزان، مع سقف تنويع (diversity cap) لكل فئة بحيث لا تهيمن فئة
واحدة على القائمة النهائية.
"""

import re
import numpy as np
from collections import defaultdict
from scipy.sparse import csr_matrix

try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity
    _SKLEARN_OK = True
except Exception:
    _SKLEARN_OK = False


# ─────────────────────────────────────────────────────────────────
# إعدادات عامة
# ─────────────────────────────────────────────────────────────────

# أوزان دمج المصادر (تُطبَّق بعد تطبيع كل مصدر إلى [0, 1])
SIGNAL_WEIGHTS = {
    "content": 0.45,    # TF-IDF + ملف المستخدم السلوكي
    "social": 0.20,     # follows
    "search": 0.15,     # سجل البحث
    "als": 0.05,        # ALS (منخفض ثابت بدل اعتباطي حسب الحجم)
    "popular": 0.15,    # شيوع عام كـ tie-breaker / تعزيز خفيف دائم
}

# أوزان نوع التفاعل لبناء ملف المستخدم السلوكي
INTERACTION_WEIGHTS = {
    "view": 1.0,
    "like": 3.0,
    "save": 4.0,
    "bookmark": 3.0,
    "complete": 5.0,
    "enroll": 4.0,
    "watch": 3.5,
    "rating": 4.0,  # يُضرب لاحقاً بالـ score الفعلي (1-5) عند توفره
}

# سقف عدد العناصر من نفس الفئة في القائمة النهائية (diversity cap)
MAX_PER_CATEGORY_RATIO = 0.6  # مثال: limit=5 → حتى 3 من نفس الفئة


def _normalize(scores: dict) -> dict:
    """يطبّع قيم dict إلى [0, 1] بقسمة min-max. آمن عند تساوي كل القيم."""
    if not scores:
        return {}
    values = list(scores.values())
    lo, hi = min(values), max(values)
    if hi - lo < 1e-9:
        return {k: 1.0 for k in scores}
    return {k: (v - lo) / (hi - lo) for k, v in scores.items()}


def _item_key(content_type: str, content_id) -> str:
    return f"{content_type}_{content_id}"


# ─────────────────────────────────────────────────────────────────
# 1) جلب كل المحتوى + بناء نص موحّد لكل عنصر (لـ TF-IDF)
# ─────────────────────────────────────────────────────────────────

def _fetch_catalog(db) -> dict:
    """
    يرجع: { item_key: {id, content_type, title, category, author,
                        image_url, rating, text} }
    """
    catalog = {}

    courses = db.table("courses").select(
        "id, title, description, category, image_url, rating"
    ).execute().data
    for r in courses:
        key = _item_key("course", r["id"])
        text = " ".join(filter(None, [r.get("title"), r.get("description"), r.get("category")]))
        catalog[key] = {
            "id": r["id"], "content_type": "course", "title": r.get("title"),
            "category": r.get("category"), "author": None,
            "image_url": r.get("image_url"), "rating": r.get("rating") or 0,
            "text": text,
        }

    books = db.table("books").select(
        "id, title, description, category, author, image_url, rating"
    ).execute().data
    for r in books:
        key = _item_key("book", r["id"])
        text = " ".join(filter(None, [r.get("title"), r.get("description"), r.get("category"), r.get("author")]))
        catalog[key] = {
            "id": r["id"], "content_type": "book", "title": r.get("title"),
            "category": r.get("category"), "author": r.get("author"),
            "image_url": r.get("image_url"), "rating": r.get("rating") or 0,
            "text": text,
        }

    articles = db.table("articles").select(
        "id, title, content, category, image_url, rating"
    ).execute().data
    for r in articles:
        key = _item_key("article", r["id"])
        snippet = (r.get("content") or "")[:300]
        text = " ".join(filter(None, [r.get("title"), snippet, r.get("category")]))
        catalog[key] = {
            "id": r["id"], "content_type": "article", "title": r.get("title"),
            "category": r.get("category"), "author": None,
            "image_url": r.get("image_url"), "rating": r.get("rating") or 0,
            "text": text,
        }

    return catalog


# ─────────────────────────────────────────────────────────────────
# 2) ملف المستخدم السلوكي (Behavioral Profile)
# ─────────────────────────────────────────────────────────────────

def _build_user_profile(db, user_id: int) -> dict:
    """
    يجمع كل إشارات المستخدم (تفاعلات + bookmarks + ratings تأتي
    أصلاً موحّدة داخل user_interactions عبر sync_interactions.py)
    ويرجع: { item_key: weight }, seen_keys (set)
    """
    interactions = db.table("user_interactions").select(
        "content_type, content_id, interaction_type, score"
    ).eq("user_id", user_id).execute().data

    item_weights: dict[str, float] = defaultdict(float)
    seen = set()

    for r in interactions:
        key = _item_key(r["content_type"], r["content_id"])
        seen.add(key)
        base = INTERACTION_WEIGHTS.get(r.get("interaction_type"), 1.0)
        score = float(r.get("score") or base)
        # نأخذ أعلى قيمة بدل الجمع لتفادي تضخيم تفاعلات مكررة بنفس العنصر
        item_weights[key] = max(item_weights[key], score)

    return item_weights, seen


# ─────────────────────────────────────────────────────────────────
# 3) Content-Based عبر TF-IDF (المحرّك الأساسي)
# ─────────────────────────────────────────────────────────────────

def get_content_based_scores(db, user_id: int, catalog: dict = None) -> dict:
    """
    يرجع dict { item_key: raw_score } غير مطبّع، حيث الـ score هو
    متوسط تشابه (cosine) العنصر مع كل عناصر ملف المستخدم، موزون
    بقوة تفاعل المستخدم مع كل عنصر مرجعي.

    إن لم يتوفر sklearn أو كان ملف المستخدم فارغاً، يرجع {}.
    """
    if not _SKLEARN_OK:
        return {}

    if catalog is None:
        catalog = _fetch_catalog(db)
    if not catalog:
        return {}

    user_weights, seen = _build_user_profile(db, user_id)
    if not user_weights:
        return {}

    keys = list(catalog.keys())
    key_pos = {k: i for i, k in enumerate(keys)}
    texts = [catalog[k]["text"] or catalog[k]["title"] or "" for k in keys]

    vectorizer = TfidfVectorizer(max_features=5000, stop_words=None)
    try:
        tfidf_matrix = vectorizer.fit_transform(texts)
    except ValueError:
        # كل النصوص فارغة
        return {}

    # متوسط موزون لمتجهات العناصر التي تفاعل معها المستخدم (profile vector)
    ref_indices, ref_weights = [], []
    for key, w in user_weights.items():
        if key in key_pos:
            ref_indices.append(key_pos[key])
            ref_weights.append(w)

    if not ref_indices:
        return {}

    ref_weights = np.array(ref_weights)
    ref_weights = ref_weights / ref_weights.sum()
    profile_vector = np.asarray(
        tfidf_matrix[ref_indices].T.dot(ref_weights)
    ).reshape(1, -1)

    sims = cosine_similarity(profile_vector, tfidf_matrix).flatten()

    scores = {}
    for key, idx in key_pos.items():
        if key in seen:
            continue  # لا نرشّح ما رآه المستخدم بالفعل
        if sims[idx] > 0:
            scores[key] = float(sims[idx])

    # نرفع أولوية المؤلف المتطابق لدى الكتب (إشارة قوية ودقيقة لا يلتقطها TF-IDF بالضرورة)
    authors_liked = {
        catalog[k]["author"]
        for k in user_weights
        if k in catalog and catalog[k].get("author")
    }
    if authors_liked:
        for key in scores:
            if catalog[key]["content_type"] == "book" and catalog[key].get("author") in authors_liked:
                scores[key] *= 1.3

    return scores


# ─────────────────────────────────────────────────────────────────
# 4) Social Proof (follows)
# ─────────────────────────────────────────────────────────────────

def get_social_scores(db, user_id: int) -> dict:
    """
    يرجع dict { item_key: raw_score } بناءً على تفاعلات/تقييمات
    من يتابعهم المستخدم الحالي. كل متابَع يساهم بوزن تفاعله مع
    العنصر؛ نجمع المساهمات من كل المتابَعين.
    """
    try:
        follows = db.table("follows").select("following_id").eq(
            "follower_id", user_id
        ).execute().data
    except Exception as e:
        print(f"social_scores follows error: {e}")
        return {}

    followed_ids = [f["following_id"] for f in follows]
    if not followed_ids:
        return {}

    try:
        rows = db.table("user_interactions").select(
            "user_id, content_type, content_id, interaction_type, score"
        ).in_("user_id", followed_ids).execute().data
    except Exception as e:
        print(f"social_scores interactions error: {e}")
        return {}

    scores: dict[str, float] = defaultdict(float)
    for r in rows:
        key = _item_key(r["content_type"], r["content_id"])
        base = INTERACTION_WEIGHTS.get(r.get("interaction_type"), 1.0)
        score = float(r.get("score") or base)
        scores[key] += score

    return dict(scores)


# ─────────────────────────────────────────────────────────────────
# 5) Search-Based (سجل البحث كنيّة صريحة)
# ─────────────────────────────────────────────────────────────────

def get_search_based_scores(db, user_id: int, catalog: dict = None) -> dict:
    """
    يرجع dict { item_key: raw_score } حسب تطابق كلمات سجل البحث
    الأخير مع عنوان/فئة/مؤلف العنصر. البحث الأحدث له وزن أعلى.
    """
    try:
        searches = db.table("search_history").select("query, created_at").eq(
            "user_id", user_id
        ).order("created_at", desc=True).limit(5).execute().data
    except Exception as e:
        print(f"search_based error: {e}")
        return {}

    keywords = [r["query"].strip() for r in searches if len((r["query"] or "").strip()) >= 2]
    if not keywords:
        return {}

    if catalog is None:
        catalog = _fetch_catalog(db)

    scores: dict[str, float] = defaultdict(float)
    n = len(keywords)
    for rank, kw in enumerate(keywords):
        kw_lower = kw.lower()
        recency_weight = (n - rank) / n  # الأحدث = وزن أعلى
        for key, item in catalog.items():
            haystack = " ".join(filter(None, [
                item.get("title"), item.get("category"), item.get("author"),
            ])).lower()
            if kw_lower in haystack:
                scores[key] += recency_weight

    return dict(scores)


# ─────────────────────────────────────────────────────────────────
# 6) Popular / Trending (Cold Start + تعزيز خفيف دائم)
# ─────────────────────────────────────────────────────────────────

def get_popular(db, limit: int = 5):
    courses = db.table("courses").select(
        "id, title, image_url, rating, category"
    ).order("rating", desc=True).limit(limit).execute().data

    books = db.table("books").select(
        "id, title, image_url, rating, category"
    ).order("likes", desc=True).limit(limit).execute().data

    articles = db.table("articles").select(
        "id, title, image_url, rating, category"
    ).order("rating", desc=True).limit(limit).execute().data

    return courses, books, articles


def get_popular_scores(catalog: dict) -> dict:
    """يحوّل تقييم/شعبية كل عنصر في الكاتالوج إلى raw score (للدمج)."""
    return {k: float(v.get("rating") or 0) for k, v in catalog.items()}


# ─────────────────────────────────────────────────────────────────
# 7) ALS Training + Recommendations (وزن منخفض، يبقى مفيداً مع نمو البيانات)
# ─────────────────────────────────────────────────────────────────

def train_model(db):
    try:
        from implicit import als

        rows = db.table("user_interactions").select(
            "user_id, content_type, content_id, score"
        ).execute().data

        if not rows:
            return None, None, None, None, None, None

        user_idx, item_idx = {}, {}
        data, row_ids, col_ids = [], [], []

        for r in rows:
            user_id = r["user_id"]
            item_id = _item_key(r["content_type"], r["content_id"])

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


def get_als_scores(model, user_idx, item_idx, items_rev, matrix, user_id: int, limit: int = 30) -> dict:
    """يرجع dict { item_key: raw_score } من ALS، أو {} إن لم يتوفر النموذج."""
    try:
        if model is None or user_id not in user_idx:
            return {}

        idx = user_idx[user_id]
        recommended_ids, weights = model.recommend(
            idx, matrix[idx], N=limit, filter_already_liked_items=True
        )

        scores = {}
        for item_pos, w in zip(recommended_ids, weights):
            key = items_rev.get(item_pos)
            if key:
                scores[key] = float(w)
        return scores

    except Exception as e:
        print(f"ALS recommend error: {e}")
        return {}


# ─────────────────────────────────────────────────────────────────
# 8) الدمج الهجين (Hybrid Fusion) + سقف التنويع
# ─────────────────────────────────────────────────────────────────

def get_hybrid_recommendations(
    db,
    user_id: int,
    limit: int = 5,
    als_bundle: dict | None = None,
):
    """
    المحرك الرئيسي. يبني الكاتالوج مرة واحدة، يستخرج كل الإشارات،
    يطبّع كل واحدة إلى [0, 1]، يجمعها بالأوزان الثابتة في
    SIGNAL_WEIGHTS، ثم يطبّق سقف تنويع للفئة قبل تقسيم النتائج
    حسب نوع المحتوى (courses / books / articles).

    يرجع: (courses, books, articles, debug_info)
    حيث كل عنصر في القوائم هو dict كامل من الكاتالوج (id, title, ...)
    مع حقل إضافي "match_score".
    """
    catalog = _fetch_catalog(db)
    if not catalog:
        return [], [], [], {"signals_used": []}

    user_weights, seen = _build_user_profile(db, user_id)

    raw_signals = {
        "content": get_content_based_scores(db, user_id, catalog=catalog),
        "social": get_social_scores(db, user_id),
        "search": get_search_based_scores(db, user_id, catalog=catalog),
        "popular": get_popular_scores(catalog),
    }
    if als_bundle and als_bundle.get("model"):
        raw_signals["als"] = get_als_scores(
            model=als_bundle["model"],
            user_idx=als_bundle["user_idx"],
            item_idx=als_bundle["item_idx"],
            items_rev=als_bundle["items"],
            matrix=als_bundle["matrix"],
            user_id=user_id,
        )
    else:
        raw_signals["als"] = {}

    signals_used = [name for name, s in raw_signals.items() if s]

    # تطبيع كل مصدر إلى [0, 1]
    normalized = {name: _normalize(scores) for name, scores in raw_signals.items()}

    # دمج موزون
    final_scores: dict[str, float] = defaultdict(float)
    for name, scores in normalized.items():
        weight = SIGNAL_WEIGHTS.get(name, 0.0)
        for key, val in scores.items():
            final_scores[key] += weight * val

    # استثناء ما رآه المستخدم بالفعل
    for key in seen:
        final_scores.pop(key, None)

    if not final_scores:
        return [], [], [], {"signals_used": signals_used}

    ranked = sorted(final_scores.items(), key=lambda x: x[1], reverse=True)

    # تقسيم حسب نوع المحتوى مع سقف تنويع الفئة داخل كل نوع
    by_type: dict[str, list] = {"course": [], "book": [], "article": []}
    category_counts: dict[str, dict[str, int]] = {"course": defaultdict(int), "book": defaultdict(int), "article": defaultdict(int)}
    max_per_category = max(1, int(limit * MAX_PER_CATEGORY_RATIO))

    for key, score in ranked:
        item = catalog.get(key)
        if not item:
            continue
        ctype = item["content_type"]
        if len(by_type[ctype]) >= limit:
            continue
        cat = item.get("category") or "_none"
        if category_counts[ctype][cat] >= max_per_category and len(by_type[ctype]) < limit:
            # تجاوز هذا العنصر مؤقتاً لتفادي هيمنة فئة واحدة، إلا إذا
            # لم يبق ما يكفي من عناصر بديلة (سيُعاد ملؤه في تمريرة fallback أدناه)
            continue
        entry = dict(item)
        entry["match_score"] = round(score, 4)
        by_type[ctype].append(entry)
        category_counts[ctype][cat] += 1

    # تمريرة fallback: إن لم نُكمل العدد المطلوب بسبب سقف التنويع، نُكمل بدونه
    for key, score in ranked:
        item = catalog.get(key)
        if not item:
            continue
        ctype = item["content_type"]
        if len(by_type[ctype]) >= limit:
            continue
        if any(e["id"] == item["id"] for e in by_type[ctype]):
            continue
        entry = dict(item)
        entry["match_score"] = round(score, 4)
        by_type[ctype].append(entry)

    debug_info = {
        "signals_used": signals_used,
        "weights": SIGNAL_WEIGHTS,
    }

    return by_type["course"], by_type["book"], by_type["article"], debug_info


# ─────────────────────────────────────────────────────────────────
# دوال محفوظة للتوافق الخلفي (تُستخدم من قبل وحدات أخرى/سكربتات قديمة)
# ─────────────────────────────────────────────────────────────────

def get_content_based(db, user_id: int, limit: int = 5):
    """
    نسخة متوافقة قديماً: ترجع (courses, books, articles) بدلاً من
    dict من الـ scores. تُستخدم كـ fallback بسيط عند عدم توفر sklearn
    أو في سكربتات قديمة لا تزال تستورد هذا الاسم.
    """
    catalog = _fetch_catalog(db)
    scores = get_content_based_scores(db, user_id, catalog=catalog)
    if not scores:
        return [], [], []

    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    courses, books, articles = [], [], []
    for key, _score in ranked:
        item = catalog.get(key)
        if not item:
            continue
        if item["content_type"] == "course" and len(courses) < limit:
            courses.append(item)
        elif item["content_type"] == "book" and len(books) < limit:
            books.append(item)
        elif item["content_type"] == "article" and len(articles) < limit:
            articles.append(item)
        if len(courses) >= limit and len(books) >= limit and len(articles) >= limit:
            break
    return courses, books, articles


def get_user_based_recommendations(db, user_id: int, limit: int = 5):
    """
    محفوظة للتوافق الخلفي فقط. الاستراتيجية الجديدة لا تعتمد على
    User-Based CF كمصدر أساسي (غير موثوق مع < 100 مستخدم)، لذا هذه
    الدالة تُعيد قوائم فارغة الآن. استُبدلت فعلياً بـ
    get_hybrid_recommendations أعلاه.
    """
    return [], [], []


def get_als_recommendations(model, user_idx, item_idx, items_rev, matrix, user_id: int, limit: int = 10):
    """نسخة متوافقة قديماً تستخدم get_als_scores داخلياً وتُعيد الشكل القديم."""
    scores = get_als_scores(model, user_idx, item_idx, items_rev, matrix, user_id, limit=limit)
    courses, books, articles = [], [], []
    for key in scores:
        if "_" not in key:
            continue
        content_type, content_id = key.split("_", 1)
        try:
            entry = {"id": int(content_id), "type": content_type}
        except ValueError:
            continue
        if content_type == "course":
            courses.append(entry)
        elif content_type == "book":
            books.append(entry)
        elif content_type == "article":
            articles.append(entry)
    return courses, books, articles