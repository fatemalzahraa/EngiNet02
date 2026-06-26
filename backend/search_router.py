"""
search_router.py - بحث ذكي بـ Groq API
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
    types: list[str] = ["courses", "books", "articles"]


def _fetch_all_content(db):
    courses  = db.table("courses").select("id, title, description, category").execute().data
    books    = db.table("books").select("id, title, description, category").execute().data
    articles_raw = db.table("articles").select("id, title, content, category").execute().data
    articles = [{"id": r["id"], "title": r["title"], "category": r["category"],
                 "description": (r.get("content") or "")[:200]} for r in articles_raw]
    return courses, books, articles


def _build_context(courses, books, articles, types):
    lines = []
    if "courses" in types:
        lines.append("=== COURSES ===")
        for c in courses:
            lines.append(f"[course:{c['id']}] {c['title']} | {c['category']} | {c.get('description','')}")
    if "books" in types:
        lines.append("=== BOOKS ===")
        for b in books:
            lines.append(f"[book:{b['id']}] {b['title']} | {b['category']} | {b.get('description','')}")
    if "articles" in types:
        lines.append("=== ARTICLES ===")
        for a in articles:
            lines.append(f"[article:{a['id']}] {a['title']} | {a['category']} | {a.get('description','')}")
    return "\n".join(lines)


@router.post("/smart")
async def smart_search(body: SearchRequest, current_user: dict = Depends(get_current_user)):
    if not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="GROQ_API_KEY not configured")
    if not body.query.strip():
        raise HTTPException(status_code=400, detail="Query cannot be empty")

    db = get_db()
    courses, books, articles = _fetch_all_content(db)
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
  "courses": [{{"id": 1, "reason": "why relevant"}}],
  "books":   [{{"id": 2, "reason": "why relevant"}}],
  "articles": [{{"id": 3, "reason": "why relevant"}}]
}}"""

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            GROQ_URL,
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            json={"model": GROQ_MODEL, "max_tokens": 1000, "temperature": 0.1,
                  "messages": [{"role": "user", "content": prompt}]},
        )

    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Groq API error: {response.text}")

    raw = response.json()["choices"][0]["message"]["content"].strip()
    if "```json" in raw:
        raw = raw.split("```json")[1].split("```")[0].strip()
    elif "```" in raw:
        raw = raw.split("```")[1].split("```")[0].strip()

    try:
        ai_result = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(status_code=502, detail="AI returned invalid response")

    def enrich(table, ai_list):
        ids = [x["id"] for x in ai_list]
        if not ids:
            return []
        rows = {r["id"]: r for r in db.table(table).select("id, title, image_url, rating, category, description").in_("id", ids).execute().data}
        return [{**rows[x["id"]], "match_reason": x.get("reason", "")} for x in ai_list if x["id"] in rows]

    return {
        "query": body.query,
        "courses":  enrich("courses",  ai_result.get("courses", [])),
        "books":    enrich("books",    ai_result.get("books", [])),
        "articles": enrich("articles", ai_result.get("articles", [])),
    }


@router.get("/simple")
def simple_search(q: str, current_user: dict = Depends(get_current_user)):
    if not q.strip():
        raise HTTPException(status_code=400, detail="Query required")

    db = get_db()

    # Supabase ilike filter
    courses  = db.table("courses").select("id, title, image_url, rating, category").ilike("title", f"%{q}%").limit(5).execute().data
    books    = db.table("books").select("id, title, image_url, rating, category").ilike("title", f"%{q}%").limit(5).execute().data
    articles = db.table("articles").select("id, title, image_url, rating, category").ilike("title", f"%{q}%").limit(5).execute().data

    return {"query": q, "courses": courses, "books": books, "articles": articles,
            "total": len(courses) + len(books) + len(articles)}