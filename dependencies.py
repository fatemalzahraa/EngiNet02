import os
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

SECRET_KEY = os.getenv("SECRET_KEY", "").strip()
if not SECRET_KEY:
    raise RuntimeError(
        "SECRET_KEY environment variable is not set.\n"
        "Generate one with: python -c \"import secrets; print(secrets.token_hex(32))\""
    )

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
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
    """Supabase ile kullanıcıya puan ekle. Tüm router'larda bu kullanılır."""
    user = db.table("users").select("points").eq("id", user_id).single().execute().data
    if user:
        db.table("users").update({"points": (user["points"] or 0) + points}).eq("id", user_id).execute()


# Geriye dönük uyumluluk için alias
def add_points(db, user_id: int, points: int) -> None:
    add_points_supabase(db, user_id, points)