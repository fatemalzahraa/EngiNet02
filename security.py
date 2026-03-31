from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return bcrypt.checkpw(
    plain_password.encode("utf-8"),
    hashed_password.encode("utf-8")
)
