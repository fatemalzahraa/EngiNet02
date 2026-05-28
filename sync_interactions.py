"""
sync_interactions.py
يملأ جدول user_interactions من البيانات الموجودة في قاعدة البيانات
"""

from database import get_db


def sync_interactions():
    db = get_db()
    cursor = db.cursor()

    print("🔄 بدء مزامنة التفاعلات...")

    steps = [
        ("course_ratings", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'course', course_id, 'rating', rating::float
            FROM course_ratings
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = EXCLUDED.score
        """),
        ("book_ratings", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'book', book_id, 'rating', rating::float
            FROM book_ratings
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = EXCLUDED.score
        """),
        ("student_courses", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'course', course_id, 'enroll', 4.0
            FROM student_courses
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = GREATEST(user_interactions.score, 4.0)
        """),
        ("bookmarks", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'book', book_id, 'bookmark', 3.0
            FROM bookmarks
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = GREATEST(user_interactions.score, 3.0)
        """),
        ("article_bookmarks", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'article', article_id, 'bookmark', 3.0
            FROM article_bookmarks
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = GREATEST(user_interactions.score, 3.0)
        """),
        ("book_likes", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'book', book_id, 'like', 2.0
            FROM likes WHERE book_id IS NOT NULL
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = GREATEST(user_interactions.score, 2.0)
        """),
        ("article_likes", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'article', article_id, 'like', 2.0
            FROM likes WHERE article_id IS NOT NULL
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = GREATEST(user_interactions.score, 2.0)
        """),
        ("course_likes", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT user_id, 'course', course_id, 'like', 2.0
            FROM course_likes
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = GREATEST(user_interactions.score, 2.0)
        """),
        ("lesson_progress", """
            INSERT INTO user_interactions (user_id, content_type, content_id, interaction_type, score)
            SELECT lp.user_id, 'course', l.course_id, 'watch', 3.5
            FROM lesson_progress lp
            JOIN lessons l ON l.id = lp.lesson_id
            WHERE lp.is_completed = true
            ON CONFLICT (user_id, content_type, content_id)
            DO UPDATE SET score = GREATEST(user_interactions.score, 3.5)
        """),
    ]

    for name, query in steps:
        try:
            cursor.execute(query)
            print(f"  ✅ {name}: {cursor.rowcount} سجل")
        except Exception as e:
            print(f"  ⚠️  {name}: {e}")

    db.commit()

    cursor.execute("SELECT COUNT(*) as total FROM user_interactions")
    total = cursor.fetchone()["total"]
    cursor.execute("SELECT COUNT(DISTINCT user_id) as users FROM user_interactions")
    users = cursor.fetchone()["users"]

    print(f"\n📊 إجمالي التفاعلات: {total} | المستخدمين: {users}")
    db.close()
    return total, users


if __name__ == "__main__":
    sync_interactions()