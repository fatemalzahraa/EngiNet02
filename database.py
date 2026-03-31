import psycopg2
import psycopg2.extras

DATABASE_URL = "postgresql://postgres:Sweetzozo847..@db.ksfrsnbfdzgtkxhswobs.supabase.co:5432/postgres"

def get_db():
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = False
    return conn
