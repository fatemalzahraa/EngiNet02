import os
import jwt as pyjwt
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
import requests

SECRET_KEY = os.getenv("SECRET_KEY", "").strip()
SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip()

if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY environment variable is not set.")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Supabase JWKS'den public key'leri çek (ES256 için)
_jwks_client = None
def _get_jwks_client():
    global _jwks_client
    if _jwks_client is None and SUPABASE_URL:
        jwks_url = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"
        _jwks_client = pyjwt.PyJWKClient(jwks_url)
    return _jwks_client

def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    email = None

    # Supabase JWT (ES256)
    client = _get_jwks_client()
    if client:
        try:
            signing_key = client.get_signing_key_from_jwt(token)
            payload = pyjwt.decode(
                token,
                signing_key.key,
                algorithms=["ES256", "RS256"],
                options={"verify_aud": False},
            )
            email = payload.get("email")
        except Exception:
            pass

    # Eski HS256
    if not email:
        try:
            payload = pyjwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            email = payload.get("sub")
        except pyjwt.PyJWTError:
            pass

    if not email:
        raise HTTPException(status_code=401, detail="Invalid token")

    # Role'ü public.users'dan oku
    from database import get_db
    db = get_db()
    user = db.table("users").select("email, role").eq("email", email).single().execute().data
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {"email": user["email"], "role": user["role"]}
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