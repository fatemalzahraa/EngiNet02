def test_protected_route_without_token(client):
    response = client.get("/profile/me")
    assert response.status_code == 401


def test_protected_route_with_invalid_token(client):
    response = client.get(
        "/profile/me",
        headers={"Authorization": "Bearer not-a-valid-jwt"},
    )
    assert response.status_code == 401


def test_ai_chat_requires_auth(client):
    response = client.post(
        "/ai/chat",
        json={
            "messages": [{"role": "user", "content": "Hello"}],
            "system_prompt": "You are a helpful assistant.",
        },
    )
    assert response.status_code == 401
