import sqlite3
from passlib.context import CryptContext

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
conn = sqlite3.connect("enginet.db")
conn.row_factory = sqlite3.Row
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
    CREATE TABLE IF NOT EXISTS posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        image_url TEXT,
        linked_course_id INTEGER,
        likes INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (linked_course_id) REFERENCES courses(id)
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
        cursor.execute("INSERT OR IGNORE INTO users (username,email,password,role,bio,profile_image,points,university) VALUES (?,?,?,?,?,?,?,?)", u)
        print(f"  👤 {u[0]}")
    except Exception as e:
        print(f"  ⚠️ {u[0]}: {e}")

# BOOKS
books = [
    ("Think Python", "Allen B. Downey", "Python, Programming", "Introduction to Python for beginners.", "https://greenteapress.com/thinkpython2/thinkpython2.pdf", "https://m.media-amazon.com/images/I/81D5y6dDnHL._AC_UF894,1000_QL80_.jpg", "English", 2016),
    ("Pro Git", "Scott Chacon", "Git, Version Control", "The complete guide to Git.", "https://git-scm.com/book/en/v2", "https://git-scm.com/images/progit2.png", "English", 2014),
    ("The Linux Command Line", "William Shotts", "Linux, Systems", "A complete introduction to the Linux command line.", "https://sourceforge.net/projects/linuxcommand/files/TLCL/19.01/TLCL-19.01.pdf", "https://m.media-amazon.com/images/I/71cqBku-rEL._UF350,350_QL50_.jpg", "English", 2019),
    ("Automate the Boring Stuff", "Al Sweigart", "Python, Automation", "Practical programming for total beginners.", "https://automatetheboringstuff.com/2e/chapter0/", "https://m.media-amazon.com/images/I/71RIZLZvXZL._AC_UF894,1000_QL80_.jpg", "English", 2020),
    ("Python Türkçe Rehber", "Yazbel", "Python, Programming", "Türkçe Python programlama rehberi.", "https://python-istihza.yazbel.com", "https://img.kitapyurdu.com/v1/getImage/fn:11623098/wh:18edcf29b/miw:200/mih:200", "Turkish", 2022),
]
for b in books:
    cursor.execute("INSERT OR IGNORE INTO books (title,author,category,description,file_url,image_url,language,publish_year) VALUES (?,?,?,?,?,?,?,?)", b)
    print(f"  📚 {b[0]}")

# ARTICLES
articles = [
    ("The Importance of Breadth and Depth in CS", "Why CS students need broad and deep knowledge.", "Computer Science", "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800", "Eng.jack", "https://i.pravatar.cc/150?img=1", 4.8, ""),
    ("Researching Online Computer Science", "How to research CS topics online.", "Education", "https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800", "Eng.sara", "https://i.pravatar.cc/150?img=5", 4.5, ""),
    ("Introduction to Machine Learning", "Beginner intro to ML.", "AI", "https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800", "Eng.ali", "https://i.pravatar.cc/150?img=3", 4.7, ""),
    ("Clean Code Principles Every Developer Should Know", "Best practices for clean code.", "Software Engineering", "https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=800", "Eng.jack", "https://i.pravatar.cc/150?img=1", 4.9, ""),
    ("Getting Started with Flutter Development", "Guide to building Flutter apps.", "Mobile", "https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=800", "Eng.sara", "https://i.pravatar.cc/150?img=5", 4.6, ""),
]
for a in articles:
    cursor.execute("INSERT OR IGNORE INTO articles (title,content,category,image_url,author_name,author_image,rating,pdf_url) VALUES (?,?,?,?,?,?,?,?)", a)
    print(f"  📄 {a[0][:45]}")

# COURSES - بيانات حقيقية من YouTube (freeCodeCamp + Traversy Media)
courses = [
    (
        "Flutter & Dart - The Complete Guide",
        "Maximilian Schwarzmüller",
        "https://i.pravatar.cc/150?img=11",
        "Master Flutter and Dart from zero to hero. Build real iOS & Android apps.",
        "Mobile Development",
        "https://storage.googleapis.com/cms-storage-bucket/ec64036b4eacc9f3fd73.svg",
        54, 4.8
    ),
    (
        "Python Full Course for Beginners",
        "Mosh Hamedani",
        "https://i.pravatar.cc/150?img=12",
        "Learn Python from scratch with hands-on projects and real-world examples.",
        "Programming",
        "https://www.python.org/static/community_logos/python-logo-generic.svg",
        6, 4.9
    ),
    (
        "Machine Learning with Python - Full Course",
        "freeCodeCamp",
        "https://i.pravatar.cc/150?img=13",
        "Learn machine learning fundamentals with Python, TensorFlow and scikit-learn.",
        "AI & Machine Learning",
        "https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=400",
        10, 4.7
    ),
    (
        "Full Stack Web Development Bootcamp",
        "Brad Traversy",
        "https://i.pravatar.cc/150?img=14",
        "HTML, CSS, JavaScript, React, Node.js and more in one complete course.",
        "Web Development",
        "https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=400",
        45, 4.8
    ),
    (
        "Data Structures & Algorithms - Full Course",
        "freeCodeCamp",
        "https://i.pravatar.cc/150?img=13",
        "Master DSA concepts essential for coding interviews and competitive programming.",
        "Computer Science",
        "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400",
        8, 4.9
    ),
]

course_ids = {}
for c in courses:
    cursor.execute("INSERT OR IGNORE INTO courses (title,instructor_name,instructor_image,description,category,image_url,duration_hours,rating) VALUES (?,?,?,?,?,?,?,?)", c)
    cursor.execute("SELECT id FROM courses WHERE title = ?", (c[0],))
    row = cursor.fetchone()
    if row:
        course_ids[c[0]] = row[0]
    print(f"  🎓 {c[0][:45]}")

# LESSONS - روابط YouTube حقيقية
lessons_flutter = [
    ("Introduction & Setup", "https://www.youtube.com/watch?v=x0uinJvhNxI", 20),
    ("Dart Basics", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=1800", 35),
    ("Flutter Widgets", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=4200", 40),
    ("Stateful vs Stateless Widgets", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=6600", 30),
    ("Navigation & Routing", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=9000", 35),
    ("State Management (Provider)", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=11400", 50),
    ("HTTP Requests & REST APIs", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=14400", 45),
    ("SQLite Local Database", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=17200", 35),
    ("Firebase Integration", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=20000", 50),
    ("Publishing to Play Store", "https://www.youtube.com/watch?v=x0uinJvhNxI&t=23000", 25),
]

lessons_python = [
    ("Python Setup & First Program", "https://www.youtube.com/watch?v=kqtD5dpn9C8", 15),
    ("Variables & Data Types", "https://www.youtube.com/watch?v=kqtD5dpn9C8&t=900", 20),
    ("Conditional Statements", "https://www.youtube.com/watch?v=kqtD5dpn9C8&t=2100", 18),
    ("Loops (for & while)", "https://www.youtube.com/watch?v=kqtD5dpn9C8&t=3300", 22),
    ("Functions", "https://www.youtube.com/watch?v=kqtD5dpn9C8&t=4800", 25),
    ("Lists & Tuples", "https://www.youtube.com/watch?v=kqtD5dpn9C8&t=6300", 20),
    ("Dictionaries", "https://www.youtube.com/watch?v=kqtD5dpn9C8&t=7800", 18),
    ("Object-Oriented Programming", "https://www.youtube.com/watch?v=kqtD5dpn9C8&t=9600", 35),
]

all_lessons = {
    "Flutter & Dart - The Complete Guide": lessons_flutter,
    "Python Full Course for Beginners": lessons_python,
}

for course_title, lessons in all_lessons.items():
    cid = course_ids.get(course_title)
    if cid:
        for i, l in enumerate(lessons):
            cursor.execute("INSERT OR IGNORE INTO lessons (course_id,title,video_url,duration_minutes,order_index) VALUES (?,?,?,?,?)",
                          (cid, l[0], l[1], l[2], i+1))
        print(f"  📝 {len(lessons)} ders → {course_title[:35]}")

# POSTS
cursor.execute("SELECT id FROM users WHERE username = 'eng_jack'")
jack = cursor.fetchone()
cursor.execute("SELECT id FROM users WHERE username = 'eng_sara'")
sara = cursor.fetchone()
cursor.execute("SELECT id FROM users WHERE username = 'eng_ali'")
ali = cursor.fetchone()
flutter_course_id = course_ids.get("Flutter & Dart - The Complete Guide")

if jack and sara and ali:
    posts = [
        (jack['id'], "Sizce yapay zekâ gelecekte programcıların yerini alacak mı? Bu konuda görüşünüz nedir?", "", None),
        (jack['id'], "A Complete Guide to the Flutter SDK & Flutter Framework for building native iOS and Android apps", "", flutter_course_id),
        (sara['id'], "What will be the output of the following code?\n\nx = [1, 2, 3]\nprint(x[::-1])", "", None),
        (ali['id'], "Machine Learning is not magic, it's mathematics. Start with the basics and build your way up!", "", None),
        (sara['id'], "Top 5 resources to learn Python in 2025: 1) Python.org docs 2) freeCodeCamp 3) Automate the Boring Stuff 4) CS50 5) Kaggle", "", None),
    ]
    for p in posts:
        cursor.execute("INSERT OR IGNORE INTO posts (user_id, content, image_url, linked_course_id) VALUES (?,?,?,?)", p)
    print(f"  📝 {len(posts)} post eklendi")

conn.commit()
conn.close()
print("\n🎉 Veritabanı hazır!")
print("  fa@gmail.com         / 12341234")
print("  jack@enginet.com     / jack123")
print("  student1@enginet.com / student123")