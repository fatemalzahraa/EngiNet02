import os
import sys

# database.py and dependencies.py read env at import time — set before importing app.
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-pytest-only-min-32-chars")
os.environ.setdefault("SUPABASE_URL", "https://test-project.supabase.co")
os.environ.setdefault("SUPABASE_KEY", "test-supabase-key")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-service-key")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from fastapi.testclient import TestClient
from main import app


@pytest.fixture
def client():
    return TestClient(app)
