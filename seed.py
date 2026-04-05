"""
Seed script for EngiNet — Supabase PostgreSQL.

Usage:
    export DATABASE_URL="postgresql://postgres:Sweetzozo847..@db.ksfrsnbfdzgtkxhswobs.supabase.co:5432/postgres"
    python seed.py
"""

import os
import psycopg2
import psycopg2.extras
from passlib.context import CryptContext

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
if not DATABASE_URL:
    raise RuntimeError("Set DATABASE_URL environment variable first.")

conn = psycopg2.connect(DATABASE_URL, cursor_factory=psycopg2.extras.RealDictCursor)
cursor = conn.cursor()

print("🌱 Seeding database…")

# ── Users ──────────────────────────────────────────────────────────────────────
users = [
    ("admin",    "fa@gmail.com",          pwd.hash("12341234"),   "admin",    "Platform Administrator", None, 0,   None),
    ("eng_jack", "jack@enginet.com",       pwd.hash("jack123"),    "engineer", "Senior Software Engineer", None, 450, "MIT"),
    ("eng_sara", "sara@enginet.com",       pwd.hash("sara123"),    "engineer", "AI & ML Specialist", None, 380, "Stanford"),
    ("eng_ali",  "ali@enginet.com",        pwd.hash("ali123"),     "engineer", "Civil Engineer", None, 290, "ITU"),
    ("student1", "student1@enginet.com",   pwd.hash("student123"), "student",  "CS Student", None, 120, "GIBTÜ"),
]
for u in users:
    try:
        cursor.execute(
            """
            INSERT INTO users (username, email, password, role, bio, profile_image, points, university)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (email) DO NOTHING
            """,
            u,
        )
        print(f"  👤 {u[0]}")
    except Exception as e:
        print(f"  ⚠️  {u[0]}: {e}")

# ── Books ──────────────────────────────────────────────────────────────────────
books = [
    ("Think Python", "Allen B. Downey", "Python, Programming",
     "Introduction to Python for beginners.",
     "https://greenteapress.com/thinkpython2/thinkpython2.pdf",
     "https://m.media-amazon.com/images/I/81D5y6dDnHL._AC_UF894,1000_QL80_.jpg", "English", 2016),
    ("Pro Git", "Scott Chacon", "Git, Version Control",
     "The complete guide to Git.", "https://git-scm.com/book/en/v2",
     "https://git-scm.com/images/progit2.png", "English", 2014),
    ("The Linux Command Line", "William Shotts", "Linux, Systems",
     "A complete introduction to the Linux command line.",
     "https://sourceforge.net/projects/linuxcommand/files/TLCL/19.01/TLCL-19.01.pdf",
     "https://m.media-amazon.com/images/I/71cqBku-rEL._UF350,350_QL50_.jpg", "English", 2019),
    ("Automate the Boring Stuff", "Al Sweigart", "Python, Automation",
     "Practical programming for total beginners.",
     "https://automatetheboringstuff.com/2e/chapter0/",
     "https://m.media-amazon.com/images/I/71RIZLZvXZL._AC_UF894,1000_QL80_.jpg", "English", 2020),
]
for b in books:
    cursor.execute(
        """
        INSERT INTO books (title, author, category, description, file_url, image_url, language, publish_year)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (title) DO NOTHING
        """,
        b,
    )
    print(f"  📚 {b[0]}")

# ── Articles ───────────────────────────────────────────────────────────────────
articles = [
    ("The Importance of Breadth and Depth in CS",
     "This article explores why CS students need both broad and deep knowledge.",
     "Computer Science", "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800",
     "Eng.jack", "https://i.pravatar.cc/150?img=1", 4.8, ""),
    ("Introduction to Machine Learning",
     "A beginner-friendly intro to ML concepts and applications.",
     "AI", "https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800",
     "Eng.ali", "https://i.pravatar.cc/150?img=3", 4.7, ""),
    ("Clean Code Principles Every Developer Should Know",
     "Best practices for writing clean and maintainable code.",
     "Software Engineering", "https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=800",
     "Eng.jack", "https://i.pravatar.cc/150?img=1", 4.9, ""),
    ("Getting Started with Flutter Development",
     "A complete guide to building your first Flutter app.",
     "Mobile Development", "https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=800",
     "Eng.sara", "https://i.pravatar.cc/150?img=5", 4.6, ""),
]
for a in articles:
    cursor.execute(
        """
        INSERT INTO articles (title, content, category, image_url, author_name, author_image, rating, pdf_url)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (title) DO NOTHING
        """,
        a,
    )
    print(f"  📄 {a[0][:50]}")

# ── Courses + Lessons ──────────────────────────────────────────────────────────
courses = [
    ("Flutter & Dart - The Complete Guide", "Maximilian Schwarzmüller",
     "https://i.pravatar.cc/150?img=11",
     "Master Flutter and Dart from zero to hero.",
     "Mobile Development",
     "https://storage.googleapis.com/cms-storage-bucket/ec64036b4eacc9f3fd73.svg", 54, 4.8),
    ("Python Full Course for Beginners", "Mosh Hamedani",
     "https://i.pravatar.cc/150?img=12",
     "Learn Python from scratch with hands-on projects.",
     "Programming",
     "https://www.python.org/static/community_logos/python-logo-generic.svg", 6, 4.9),
    ("Machine Learning with Python", "freeCodeCamp",
     "https://i.pravatar.cc/150?img=13",
     "Learn ML fundamentals with Python and scikit-learn.",
     "AI & Machine Learning",
     "https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=400", 10, 4.7),
    ("Full Stack Web Development Bootcamp", "Brad Traversy",
     "https://i.pravatar.cc/150?img=14",
     "HTML, CSS, JavaScript, React, Node.js and more.",
     "Web Development",
     "https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400", 45, 4.8),
    ("Data Structures & Algorithms", "freeCodeCamp",
     "https://i.pravatar.cc/150?img=13",
     "Master DSA for coding interviews.",
     "Computer Science",
     "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400", 8, 4.9),
]

course_ids = {}
for c in courses:
    cursor.execute(
        """
        INSERT INTO courses (title, instructor_name, instructor_image, description,
                             category, image_url, duration_hours, rating)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (title) DO NOTHING
        RETURNING id
        """,
        c,
    )
    row = cursor.fetchone()
    if row:
        course_ids[c[0]] = row["id"]
    else:
        cursor.execute("SELECT id FROM courses WHERE title = %s", (c[0],))
        r = cursor.fetchone()
        if r:
            course_ids[c[0]] = r["id"]
    print(f"  🎓 {c[0][:50]}")

# Lessons for Flutter course
flutter_id = course_ids.get("Flutter & Dart - The Complete Guide")
if flutter_id:
    lessons = [
        ("Introduction & Setup", "https://www.youtube.com/watch?v=x0uinJvhNxI", 20, 1),
        ("Dart Basics", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=1800", 35, 2),
        ("Flutter Widgets", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=4200", 40, 3),
        ("Stateful vs Stateless", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=6600", 30, 4),
        ("Navigation & Routing", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=9000", 35, 5),
        ("State Management", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=11400", 50, 6),
        ("HTTP Requests & APIs", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=14400", 45, 7),
        ("SQLite Local Database", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=17200", 35, 8),
        ("Firebase Integration", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=20000", 50, 9),
        ("Publishing to Play Store", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=23000", 25, 10),
    ]
    for l in lessons:
        cursor.execute(
            """
            INSERT INTO lessons (course_id, title, video_url, duration_minutes, order_index)
            VALUES (%s,%s,%s,%s,%s)
            ON CONFLICT (course_id, title) DO NOTHING
            """,
            (flutter_id, l[0], l[1], l[2], l[3]),
        )
    print(f"  📝 {len(lessons)} lessons → Flutter course")

conn.commit()
conn.close()
print("\n✅ Database seeded successfully!")
print("   fa@gmail.com          / 12341234")
print("   jack@enginet.com      / jack123")
print("   student1@enginet.com  / student123")