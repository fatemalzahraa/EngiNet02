import os
import psycopg

# Supabase PostgreSQL connection string
# Format: postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()


def get_db():
    if not DATABASE_URL:
        raise RuntimeError(
            "DATABASE_URL is not configured. "
            "Set it to your Supabase PostgreSQL connection string."
        )
        conn = psycopg.connect(DATABASE_URL, row_factory=psycopg.rows.dict_row)
    return conn