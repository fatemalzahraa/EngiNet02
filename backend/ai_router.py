import os
import requests
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List
from dependencies import get_current_user

router = APIRouter(prefix="/ai", tags=["AI"])

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama-3.3-70b-versatile"


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    system_prompt: str


@router.post("/chat")
def ai_chat(
    body: ChatRequest,
    current_user: dict = Depends(get_current_user),
):
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY not configured")

    payload = {
        "model": GROQ_MODEL,
        "max_tokens": 1500,
        "temperature": 0.7,
        "messages": [
            {"role": "system", "content": body.system_prompt},
            *[{"role": m.role, "content": m.content} for m in body.messages],
        ],
    }

    try:
        response = requests.post(
            GROQ_URL,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {GROQ_API_KEY}",
            },
            json=payload,
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        reply = data["choices"][0]["message"]["content"]
        return {"reply": reply}

    except requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="AI service timeout")
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=502, detail=f"AI service error: {str(e)}")