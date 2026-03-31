from fastapi import APIRouter, HTTPException, Depends
from models import User
from auth import create_access_token
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


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
    try:
        payload = jwt.decode(token, "secret_demo_key", algorithms=["HS256"])
        email = payload.get("sub")
        if not email:
            raise HTTPException(status_code=401, detail="Invalid token")
        return {"message": f"Hello {email}, you are authenticated"}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
