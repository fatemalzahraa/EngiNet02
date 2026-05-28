"""
search_router.py - بحث ذكي بـ Groq API
يفهم المعنى وليس فقط الكلمات
"""

import os
import json
import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from database import get_db
from dependencies import get_current_user

router = APIRouter(prefix="/search", tags=["Smart Search"])

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "").strip()
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama-3.3-70b-versatile"


class SearchRequest(BaseModel):
    query: str
    types: list[str] = ["courses", "books", "articles"]  # ما يريد البحث فيه


# ── مساعد: جلب كل المحتوى من DB ────────────────────────────
def _fetch_all_content(cursor):
    cursor.execute("SELECT id, title, description, category FROM courses")
    courses = [dict(r) for r in cursor.fetchall()]

    cursor.execute("SELECT id, title, description, category FROM books")
    books = [dict(r) for r in cursor.fetchall()]

    cursor.execute("SELECT id, title, content, category FROM articles")
    articles = [
        {
            "id": r["id"],
            "title": r["title"],
            "description": r["content"][:200] if r["content"] else "",
            "category": r["category"],
        }
        for r in cursor.fetchall()
    ]

    return courses, books, articles


# ── مساعد: بناء context للـ Groq ───────────────────────────
def _build_context(courses, books, articles, types):
    lines = []

    if "courses" in types:
        lines.append("=== COURSES ===")
        for c in courses:
            lines.append(
                f"[course:{c['id']}] {c['title']} | category: {c['category']} | {c['description'] or ''}"
            )

    if "books" in types:
        lines.append("=== BOOKS ===")
        for b in books:
            lines.append(
                f"[book:{b['id']}] {b['title']} | category: {b['category']} | {b['description'] or ''}"
            )

    if "articles" in types:
        lines.append("=== ARTICLES ===")
        for a in articles:
            lines.append(
                f"[article:{a['id']}] {a['title']} | category: {a['category']} | {a['description'] or ''}"
            )

    return "\n".join(lines)


# ── POST /search/smart ──────────────────────────────────────
@router.post("/smart")
async def smart_search(
    body: SearchRequest,
    current_user: dict = Depends(get_current_user),
):
    if not GROQ_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GROQ_API_KEY not configured",
        )

    if not body.query.strip():
        raise HTTPException(status_code=400, detail="Query cannot be empty")

    db = get_db()
    try:
        cursor = db.cursor()
        courses, books, articles = _fetch_all_content(cursor)

        context = _build_context(courses, books, articles, body.types)

        prompt = f"""You are a smart search engine for an engineering education platform called EngiNet.

Available content:
{context}

User search query: "{body.query}"

Instructions:
- Understand the meaning and intent of the query (not just keywords)
- Return the most relevant items (max 5 per type)
- Support Arabic and English queries
- Return ONLY valid JSON, no extra text

Return format:
{{
  "courses": [{{ "id": 1, "reason": "why relevant" }}],
  "books":   [{{ "id": 2, "reason": "why relevant" }}],
  "articles": [{{ "id": 3, "reason": "why relevant" }}]
}}

If nothing relevant found for a type, return empty array [].
"""

        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                GROQ_URL,
                headers={
                    "Authorization": f"Bearer {GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": GROQ_MODEL,
                    "max_tokens": 1000,
                    "temperature": 0.1,
                    "messages": [{"role": "user", "content": prompt}],
                },
            )

        if response.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=f"Groq API error: {response.text}",
            )

        raw = response.json()["choices"][0]["message"]["content"].strip()

        # تنظيف الـ JSON
        if "```json" in raw:
            raw = raw.split("```json")[1].split("```")[0].strip()
        elif "```" in raw:
            raw = raw.split("```")[1].split("```")[0].strip()

        ai_result = json.loads(raw)

        # ── جلب تفاصيل النتائج من DB ─────────────────────
        def enrich_courses(ids):
            if not ids:
                return []
            phs = ",".join(["%s"] * len(ids))
            cursor.execute(
                f"SELECT id, title, image_url, rating, category, description FROM courses WHERE id IN ({phs})",
                ids,
            )
            rows = {r["id"]: dict(r) for r in cursor.fetchall()}
            return [
                {**rows[x["id"]], "match_reason": x.get("reason", "")}
                for x in ai_result.get("courses", [])
                if x["id"] in rows
            ]

        def enrich_books(ids):
            if not ids:
                return []
            phs = ",".join(["%s"] * len(ids))
            cursor.execute(
                f"SELECT id, title, image_url, rating, category, description FROM books WHERE id IN ({phs})",
                ids,
            )
            rows = {r["id"]: dict(r) for r in cursor.fetchall()}
            return [
                {**rows[x["id"]], "match_reason": x.get("reason", "")}
                for x in ai_result.get("books", [])
                if x["id"] in rows
            ]

        def enrich_articles(ids):
            if not ids:
                return []
            phs = ",".join(["%s"] * len(ids))
            cursor.execute(
                f"SELECT id, title, image_url, rating, category FROM articles WHERE id IN ({phs})",
                ids,
            )
            rows = {r["id"]: dict(r) for r in cursor.fetchall()}
            return [
                {**rows[x["id"]], "match_reason": x.get("reason", "")}
                for x in ai_result.get("articles", [])
                if x["id"] in rows
            ]

        course_ids = [x["id"] for x in ai_result.get("courses", [])]
        book_ids = [x["id"] for x in ai_result.get("books", [])]
        article_ids = [x["id"] for x in ai_result.get("articles", [])]

        return {
            "query": body.query,
            "courses": enrich_courses(course_ids),
            "books": enrich_books(book_ids),
            "articles": enrich_articles(article_ids),
            "total": len(course_ids) + len(book_ids) + len(article_ids),
        }

    except json.JSONDecodeError:
        raise HTTPException(
            status_code=502, detail="AI returned invalid response"
        )
    finally:
        db.close()


# ── GET /search/simple?q=... ────────────────────────────────
@router.get("/simple")
def simple_search(
    q: str,
    current_user: dict = Depends(get_current_user),
):
    """بحث عادي كـ fallback"""
    if not q.strip():
        raise HTTPException(status_code=400, detail="Query required")

    db = get_db()
    try:
        cursor = db.cursor()
        pattern = f"%{q}%"

        cursor.execute(
            "SELECT id, title, image_url, rating, category FROM courses WHERE title ILIKE %s OR description ILIKE %s LIMIT 5",
            (pattern, pattern),
        )
        courses = [dict(r) for r in cursor.fetchall()]

        cursor.execute(
            "SELECT id, title, image_url, rating, category FROM books WHERE title ILIKE %s OR description ILIKE %s LIMIT 5",
            (pattern, pattern),
        )
        books = [dict(r) for r in cursor.fetchall()]

        cursor.execute(
            "SELECT id, title, image_url, rating, category FROM articles WHERE title ILIKE %s OR content ILIKE %s LIMIT 5",
            (pattern, pattern),
        )
        articles = [dict(r) for r in cursor.fetchall()]

        return {
            "query": q,
            "courses": courses,
            "books": books,
            "articles": articles,
            "total": len(courses) + len(books) + len(articles),
        }
    finally:
        db.close()