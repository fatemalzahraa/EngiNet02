from pydantic import BaseModel, EmailStr
from typing import Optional


class User(BaseModel):
    username: str
    email: str
    password: str
    role: str = "student"


class Book(BaseModel):
    title: str
    author: str
    category: str
    description: Optional[str] = ""
    file_url: str
    image_url: Optional[str] = ""
    language: Optional[str] = "English"
    publish_year: Optional[int] = 2024