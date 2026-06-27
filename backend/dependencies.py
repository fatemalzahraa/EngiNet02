import os
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

SECRET_KEY = os.getenv("SECRET_KEY", "").strip()
SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "").strip()

if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY environment variable is not set.")

ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    for secret, algorithms in [
        (SUPABASE_JWT_SECRET, ["HS256", "ES256"]),
        (SECRET_KEY, ["HS256"]),
    ]:
        if not secret:
            continue
        try:
            payload = jwt.decode(
                token,
                secret,
                algorithms=algorithms,
                options={"verify_aud": False},
            )
            email = payload.get("email")
            role = payload.get("user_metadata", {}).get("role", "student")
            if email:
                return {"email": email, "role": role}
        except JWTError:
            continue

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