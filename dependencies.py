import os
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

# ===================== CONFIG =====================
# المفتاح السري يُقرأ من environment variable فقط
# لتشغيل المشروع: export SECRET_KEY="your_strong_random_key_here"
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError(
        "SECRET_KEY environment variable is not set. "
        "Run: export SECRET_KEY='your_strong_random_key_here'"
    )

ALGORITHM = "HS256"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    """
    تحقق من JWT token وأرجع بيانات المستخدم.
    يُستخدم كـ Depends في جميع الـ routers.
    """
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
    """
    Dependency للتحقق من صلاحية المستخدم.
    مثال: Depends(require_role("engineer", "admin"))
    """
    def _check(current_user: dict = Depends(get_current_user)):
        if current_user["role"] not in allowed_roles:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. Required roles: {list(allowed_roles)}"
            )
        return current_user
    return _check


def add_points(cursor, user_id: int, points: int) -> None:
    """
    أضف نقاط للمستخدم. تُستخدم في جميع الـ routers.
    """
    cursor.execute(
        "UPDATE users SET points = points + %s WHERE id = %s",
        (points, user_id)
    )