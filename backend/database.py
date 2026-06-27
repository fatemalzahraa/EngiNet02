import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()  # reads the .env file

SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip()
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "").strip()  # match the .env key name

if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("SUPABASE_URL ve SUPABASE_KEY environment variable'ları set edilmeli.")

def get_db() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)