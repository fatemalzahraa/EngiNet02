"""
sync_interactions.py
يملأ جدول user_interactions من البيانات الموجودة
"""

from database import get_db


def _upsert(db, records: list):
    if not records:
        return 0
    db.table("user_interactions").upsert(records, on_conflict="user_id,content_type,content_id").execute()
    return len(records)


def sync_interactions():
    db = get_db()
    print("🔄 بدء مزامنة التفاعلات...")
    total_synced = 0

    # ── course_ratings ──
    try:
        rows = db.table("course_ratings").select("user_id, course_id, rating").execute().data
        records = [{"user_id": r["user_id"], "content_type": "course", "content_id": r["course_id"],
                    "interaction_type": "rating", "score": float(r["rating"])} for r in rows]
        n = _upsert(db, records)
        print(f"  ✅ course_ratings: {n}")
        total_synced += n
    except Exception as e:
        print(f"  ⚠️  course_ratings: {e}")

    # ── book_ratings ──
    try:
        rows = db.table("book_ratings").select("user_id, book_id, rating").execute().data
        records = [{"user_id": r["user_id"], "content_type": "book", "content_id": r["book_id"],
                    "interaction_type": "rating", "score": float(r["rating"])} for r in rows]
        n = _upsert(db, records)
        print(f"  ✅ book_ratings: {n}")
        total_synced += n
    except Exception as e:
        print(f"  ⚠️  book_ratings: {e}")

    # ── student_courses (enroll) ──
    try:
        rows = db.table("student_courses").select("user_id, course_id").execute().data
        records = [{"user_id": r["user_id"], "content_type": "course", "content_id": r["course_id"],
                    "interaction_type": "enroll", "score": 4.0} for r in rows]
        n = _upsert(db, records)
        print(f"  ✅ student_courses: {n}")
        total_synced += n
    except Exception as e:
        print(f"  ⚠️  student_courses: {e}")

    # ── bookmarks ──
    try:
        rows = db.table("bookmarks").select("user_id, book_id").execute().data
        records = [{"user_id": r["user_id"], "content_type": "book", "content_id": r["book_id"],
                    "interaction_type": "bookmark", "score": 3.0} for r in rows]
        n = _upsert(db, records)
        print(f"  ✅ bookmarks: {n}")
        total_synced += n
    except Exception as e:
        print(f"  ⚠️  bookmarks: {e}")

    # ── article_bookmarks ──
    try:
        rows = db.table("article_bookmarks").select("user_id, article_id").execute().data
        records = [{"user_id": r["user_id"], "content_type": "article", "content_id": r["article_id"],
                    "interaction_type": "bookmark", "score": 3.0} for r in rows]
        n = _upsert(db, records)
        print(f"  ✅ article_bookmarks: {n}")
        total_synced += n
    except Exception as e:
        print(f"  ⚠️  article_bookmarks: {e}")

    # ── book_likes ──
    try:
        rows = db.table("book_likes").select("user_id, book_id").execute().data
        records = [{"user_id": r["user_id"], "content_type": "book", "content_id": r["book_id"],
                    "interaction_type": "like", "score": 2.0} for r in rows]
        n = _upsert(db, records)
        print(f"  ✅ book_likes: {n}")
        total_synced += n
    except Exception as e:
        print(f"  ⚠️  book_likes: {e}")

    # ── lesson_progress ──
    try:
        rows = db.table("lesson_progress").select("user_id, lesson_id").eq("is_completed", True).execute().data
        lesson_ids = list({r["lesson_id"] for r in rows})
        if lesson_ids:
            lessons = db.table("lessons").select("id, course_id").in_("id", lesson_ids).execute().data
            lesson_map = {l["id"]: l["course_id"] for l in lessons}
            records = [{"user_id": r["user_id"], "content_type": "course",
                        "content_id": lesson_map[r["lesson_id"]],
                        "interaction_type": "watch", "score": 3.5}
                       for r in rows if r["lesson_id"] in lesson_map]
            n = _upsert(db, records)
            print(f"  ✅ lesson_progress: {n}")
            total_synced += n
    except Exception as e:
        print(f"  ⚠️  lesson_progress: {e}")

    # ── إجمالي ──
    stats = db.table("user_interactions").select("user_id", count="exact").execute()
    total = stats.count or 0
    users_stats = db.table("user_interactions").select("user_id").execute().data
    users = len({r["user_id"] for r in users_stats})

    print(f"\n📊 إجمالي التفاعلات: {total} | المستخدمين: {users}")
    return total, users


if __name__ == "__main__":
    sync_interactions()