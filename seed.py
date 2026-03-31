import sqlite3
from passlib.context import CryptContext

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
conn = sqlite3.connect("enginet.db")
cursor = conn.cursor()

print("🌱 başladık..")