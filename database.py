import psycopg2
import psycopg2.extras
import os
 
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:Sweetzozo847..@db.ksfrsnbfdzgtkxhswobs.supabase.co:5432/postgres")
 
def get_db():
    conn = psycopg2.connect(DATABASE_URL, cursor_factory=psycopg2.extras.RealDictCursor)
    return conn



