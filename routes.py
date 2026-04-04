from fastapi import APIRouter, HTTPException, Depends
from models import User
from auth import create_access_token, decode_access_token, oauth2_scheme

router = APIRouter()


fake_db = {}

@router.post("/register")
def register(user: User):
    if user.email in fake_db:
        raise HTTPException(status_code=400, detail="Email already registered")
  
    fake_db[user.email] = {
        "username": user.username,
        "password": user.password,
        "role": user.role
    }
    token = create_access_token({"sub": user.email})
    return {"access_token": token, "token_type": "bearer"}

@router.post("/token")
def login(form_data: User):
    user = fake_db.get(form_data.email)
    if not user or user["password"] != form_data.password:
        raise HTTPException(status_code=400, detail="Incorrect credentials")
    token = create_access_token({"sub": form_data.email})
    return {"access_token": token, "token_type": "bearer"}

@router.get("/protected")
def protected(token: str = Depends(oauth2_scheme)):
    payload = decode_access_token(token)
    email = payload.get("sub")
    if not email:
        raise HTTPException(status_code=401, detail="Invalid token")
    return {"message": f"Hello {email}, you are authenticated"}
