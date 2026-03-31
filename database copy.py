import sqlite3
from passlib.context import CryptContext

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
conn = sqlite3.connect("enginet.db")
cursor = conn.cursor()

cursor.executescript("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        bio TEXT,
        profile_image TEXT,
        points INTEGER DEFAULT 0,
        university TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        author TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        file_url TEXT NOT NULL,
        image_url TEXT,
        language TEXT DEFAULT 'English',
        publish_year INTEGER,
        likes INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        content TEXT NOT NULL,
        category TEXT,
        image_url TEXT,
        author_name TEXT,
        author_image TEXT,
        rating REAL DEFAULT 0.0,
        pdf_url TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        instructor_name TEXT,
        instructor_image TEXT,
        description TEXT,
        category TEXT,
        image_url TEXT,
        duration_hours INTEGER DEFAULT 0,
        rating REAL DEFAULT 0.0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS lessons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        video_url TEXT,
        duration_minutes INTEGER DEFAULT 0,
        order_index INTEGER DEFAULT 0,
        UNIQUE(course_id, title),
        FOREIGN KEY (course_id) REFERENCES courses(id)
    );

    CREATE TABLE IF NOT EXISTS lesson_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        lesson_id INTEGER NOT NULL,
        is_completed INTEGER DEFAULT 0,
        UNIQUE(user_id, lesson_id),
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
    );

    CREATE TABLE IF NOT EXISTS questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT,
        likes INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        is_accepted INTEGER DEFAULT 0,
        likes INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (question_id) REFERENCES questions(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
    );
""")

print("✅ Tablolar oluşturuldu!")

# USERS
users = [
    ("admin",    "fa@gmail.com",          pwd.hash("12341234"),   "admin",    "Platform Administrator", None, 0,   None),
    ("eng_jack", "jack@enginet.com",       pwd.hash("jack123"),    "engineer", "Senior Software Engineer", None, 450, "MIT"),
    ("eng_sara", "sara@enginet.com",       pwd.hash("sara123"),    "engineer", "AI & ML Specialist", None, 380, "Stanford"),
    ("eng_ali",  "ali@enginet.com",        pwd.hash("ali123"),     "engineer", "Civil Engineer", None, 290, "ITU"),
    ("student1", "student1@enginet.com",   pwd.hash("student123"), "student",  "CS Student", None, 120, "GIBTÜ"),
]
for u in users:
    try:
        cursor.execute("""
            INSERT OR IGNORE INTO users (username, email, password, role, bio, profile_image, points, university)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, u)
        print(f"  👤 {u[0]}")
    except Exception as e:
        print(f"  ⚠️ {u[0]}: {e}")

# BOOKS
books = [
    ("Think Python", "Allen B. Downey", "Python, Programming",
     "Introduction to Python for beginners.",
     "https://greenteapress.com/thinkpython2/thinkpython2.pdf",
     "https://m.media-amazon.com/images/I/81D5y6dDnHL._AC_UF894,1000_QL80_.jpg", "English", 2016),
    ("Pro Git", "Scott Chacon", "Git, Version Control",
     "The complete guide to Git.",
     "https://git-scm.com/book/en/v2",
     "https://git-scm.com/images/progit2.png", "English", 2014),
    ("The Linux Command Line", "William Shotts", "Linux, Systems",
     "A complete introduction to the Linux command line.",
     "https://sourceforge.net/projects/linuxcommand/files/TLCL/19.01/TLCL-19.01.pdf",
     "https://m.media-amazon.com/images/I/71cqBku-rEL._UF350,350_QL50_.jpg", "English", 2019),
    ("Automate the Boring Stuff", "Al Sweigart", "Python, Automation",
     "Practical programming for total beginners.",
     "https://automatetheboringstuff.com/2e/chapter0/",
     "https://m.media-amazon.com/images/I/71RIZLZvXZL._AC_UF894,1000_QL80_.jpg", "English", 2020),
    ("Python Türkçe Rehber", "Yazbel", "Python, Programming",
     "Türkçe Python programlama rehberi.",
     "https://python-istihza.yazbel.com",
     "https://img.kitapyurdu.com/v1/getImage/fn:11623098/wh:18edcf29b/miw:200/mih:200", "Turkish", 2022),
]
for b in books:
    cursor.execute("""
        INSERT OR IGNORE INTO books (title, author, category, description, file_url, image_url, language, publish_year)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, b)
    print(f"  📚 {b[0]}")

# ARTICLES
articles = [
    ("The Importance of Breadth and Depth in CS",
     "This article explores why CS students need both broad and deep knowledge.",
     "Computer Science", "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800",
     "Eng.jack", "https://i.pravatar.cc/150?img=1", 4.8, ""),
    ("Researching Online Computer Science",
     "How to effectively research CS topics online.",
     "Education", "https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800",
     "Eng.sara", "https://i.pravatar.cc/150?img=5", 4.5, ""),
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
    cursor.execute("""
        INSERT OR IGNORE INTO articles (title, content, category, image_url, author_name, author_image, rating, pdf_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, a)
    print(f"  📄 {a[0][:45]}")

# COURSES
courses = [
    ("Flutter & Dart - The Complete Guide [2025 Edition]", "Eng.jack", "https://i.pravatar.cc/150?img=1",
     "Master Flutter and Dart from scratch.", "Mobile",
     "https://upload.wikimedia.org/wikipedia/commons/1/17/Google-flutter-logo.png", 54, 4.8),
    ("Python for Beginners", "Eng.sara", "https://i.pravatar.cc/150?img=5",
     "Learn Python from zero to hero.", "Programming",
     "https://upload.wikimedia.org/wikipedia/commons/c/c3/Python-logo-notext.svg", 20, 4.6),
    ("Machine Learning A-Z", "Eng.ali", "https://i.pravatar.cc/150?img=3",
     "Complete ML course with real projects.", "AI",
     "https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=400", 35, 4.7),
    ("Web Development Bootcamp", "Eng.jack", "https://i.pravatar.cc/150?img=1",
     "Full stack web development course.", "Web",
     "https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400", 45, 4.9),
    ("Data Structures & Algorithms", "Eng.sara", "https://i.pravatar.cc/150?img=5",
     "Master DSA for interviews.", "CS",
     "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400", 30, 4.8),
]

course_ids = {}
for c in courses:
    cursor.execute("""
        INSERT OR IGNORE INTO courses (title, instructor_name, instructor_image, description, category, image_url, duration_hours, rating)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, c)
    cursor.execute("SELECT id FROM courses WHERE title = ?", (c[0],))
    row = cursor.fetchone()
    if row:
        course_ids[c[0]] = row[0]
    print(f"  🎓 {c[0][:40]}")

# LESSONS للكورس الأول فقط
lessons_course1 = [
    ("Introduction & Setup",  "https://www.youtube.com/watch?v=x0uinJvhNxI", 15),
    ("Dart Basics",           "https://www.youtube.com/watch?v=x0uinJvhNxI", 30),
    ("Flutter Widgets",       "https://www.youtube.com/watch?v=x0uinJvhNxI", 45),
    ("Stateful vs Stateless", "https://www.youtube.com/watch?v=x0uinJvhNxI", 25),
    ("Navigation & Routing",  "https://www.youtube.com/watch?v=x0uinJvhNxI", 35),
    ("State Management",      "https://www.youtube.com/watch?v=x0uinJvhNxI", 50),
    ("HTTP & APIs",           "https://www.youtube.com/watch?v=x0uinJvhNxI", 40),
    ("SQLite Database",       "https://www.youtube.com/watch?v=x0uinJvhNxI", 30),
    ("Firebase Integration",  "https://www.youtube.com/watch?v=x0uinJvhNxI", 45),
    ("Publishing the App",    "https://www.youtube.com/watch?v=x0uinJvhNxI", 20),
]

flutter_id = course_ids.get("Flutter & Dart - The Complete Guide [2025 Edition]")
if flutter_id:
    for i, l in enumerate(lessons_course1):
        cursor.execute("""
            INSERT OR IGNORE INTO lessons (course_id, title, video_url, duration_minutes, order_index)
            VALUES (?, ?, ?, ?, ?)
        """, (flutter_id, l[0], l[1], l[2], i + 1))
    print(f"  📝 {len(lessons_course1)} ders eklendi")

conn.commit()
conn.close()
print("\n🎉 Veritabanı hazır!")
print("  fa@gmail.com         / 12341234")
print("  jack@enginet.com     / jack123")
print("  student1@enginet.com / student123")