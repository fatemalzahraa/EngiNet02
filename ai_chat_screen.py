from fastapi import FastAPI
from pydantic import BaseModel
from openai import OpenAI

app = FastAPI()

OPENAI_API_KEY = "...-y9Y"

client = OpenAI(api_key=OPENAI_API_KEY)

class ChatRequest(BaseModel):
    message: str

@app.post("/chat")
def chat(req: ChatRequest):
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "أنت مساعد ذكي"},
            {"role": "user", "content": req.message}
        ]
    )

    reply = response.choices[0].message.content

    return {"reply": reply}