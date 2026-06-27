from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_protected_route_without_token():
    response = client.get("/profile/me")
    assert response.status_code == 401
