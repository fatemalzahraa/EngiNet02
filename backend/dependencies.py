import os
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

SECRET_KEY = os.getenv("SECRET_KEY", "").strip()
SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "").strip()

if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY environment variable is not set.")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    # Önce Supabase JWT'yi dene
    if SUPABASE_JWT_SECRET:
        try:
            payload = jwt.decode(token, SUPABASE_JWT_SECRET, algorithms=[ALGORITHM], options={"verify_aud": False})
            email: str = payload.get("email")
            role: str = payload.get("user_metadata", {}).get("role", "student")
            if email:
                return {"email": email, "role": role}
        except JWTError:
            pass

    # Sonra kendi SECRET_KEY ile dene (eski kullanıcılar için)
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        role: str = payload.get("role", "student")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return {"email": email, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

def require_role(*allowed_roles: str):
    def _check(current_user: dict = Depends(get_current_user)):
        if current_user["role"] not in allowed_roles:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. Required roles: {list(allowed_roles)}"
            )
        return current_user
    return _check

def add_points_supabase(db, user_id: int, points: int) -> None:
    user = db.table("users").select("points").eq("id", user_id).single().execute().data
    if user:
        db.table("users").update({"points": (user["points"] or 0) + points}).eq("id", user_id).execute()

def add_points(db, user_id: int, points: int) -> None:
    add_points_supabase(db, user_id, points)