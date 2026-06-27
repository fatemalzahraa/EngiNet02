import pytest
from unittest.mock import MagicMock, patch


def make_mock_db(interactions=None, courses=None, books=None, articles=None):
    """Test için sahte Supabase client oluşturur."""
    db = MagicMock()
    
    def table_mock(name):
        t = MagicMock()
        chain = MagicMock()
        
        if name == "user_interactions":
            chain.execute.return_value.data = interactions or []
        elif name == "courses":
            chain.execute.return_value.data = courses or []
        elif name == "books":
            chain.execute.return_value.data = books or []
        elif name == "articles":
            chain.execute.return_value.data = articles or []
        elif name == "follows":
            chain.execute.return_value.data = []
        elif name == "search_history":
            chain.execute.return_value.data = []
        else:
            chain.execute.return_value.data = []
        
        t.select.return_value = chain
        chain.eq.return_value = chain
        chain.in_.return_value = chain
        chain.order.return_value = chain
        chain.limit.return_value = chain
        chain.desc.return_value = chain
        
        return t
    
    db.table.side_effect = table_mock
    return db


class TestGetPopular:
    def test_returns_three_lists(self):
        from recommender import get_popular
        
        mock_courses = [{"id": 1, "title": "Python", "rating": 4.5}]
        mock_books = [{"id": 1, "title": "Clean Code", "likes": 100}]
        mock_articles = [{"id": 1, "title": "AI Article", "rating": 4.0}]
        
        db = make_mock_db(
            courses=mock_courses,
            books=mock_books,
            articles=mock_articles
        )
        
        courses, books, articles = get_popular(db, limit=5)
        
        assert isinstance(courses, list)
        assert isinstance(books, list)
        assert isinstance(articles, list)

    def test_respects_limit(self):
        from recommender import get_popular
        
        mock_courses = [{"id": i, "title": f"Course {i}", "rating": 4.0} for i in range(10)]
        db = make_mock_db(courses=mock_courses)
        
        courses, _, _ = get_popular(db, limit=3)
        assert len(courses) <= 3

    def test_empty_database(self):
        from recommender import get_popular
        db = make_mock_db()
        courses, books, articles = get_popular(db)
        assert courses == []
        assert books == []
        assert articles == []


class TestNormalize:
    def test_normalize_basic(self):
        from recommender import _normalize
        scores = {"a": 0.0, "b": 5.0, "c": 10.0}
        result = _normalize(scores)
        assert result["a"] == 0.0
        assert result["c"] == 1.0
        assert result["b"] == 0.5

    def test_normalize_empty(self):
        from recommender import _normalize
        assert _normalize({}) == {}

    def test_normalize_all_same(self):
        from recommender import _normalize
        scores = {"a": 5.0, "b": 5.0}
        result = _normalize(scores)
        assert result["a"] == 1.0
        assert result["b"] == 1.0


class TestBuildUserProfile:
    def test_empty_interactions(self):
        from recommender import _build_user_profile
        db = make_mock_db(interactions=[])
        weights, seen = _build_user_profile(db, user_id=1)
        assert weights == {}
        assert seen == set()

    def test_single_interaction(self):
        from recommender import _build_user_profile
        db = make_mock_db(interactions=[
            {"content_type": "course", "content_id": 1,
             "interaction_type": "like", "score": 3.0}
        ])
        weights, seen = _build_user_profile(db, user_id=1)
        assert "course_1" in seen
        assert "course_1" in weights
        assert weights["course_1"] == 3.0

    def test_higher_weight_wins(self):
        """Aynı item için en yüksek ağırlık kazanmalı."""
        from recommender import _build_user_profile
        db = make_mock_db(interactions=[
            {"content_type": "book", "content_id": 5,
             "interaction_type": "view", "score": 1.0},
            {"content_type": "book", "content_id": 5,
             "interaction_type": "like", "score": 3.0},
        ])
        weights, _ = _build_user_profile(db, user_id=1)
        assert weights["book_5"] == 3.0


class TestSecurity:
    def test_otp_is_6_digits(self):
        import secrets
        for _ in range(100):
            code = f"{secrets.randbelow(1000000):06d}"
            assert len(code) == 6
            assert code.isdigit()
            assert int(code) >= 0
            assert int(code) <= 999999

    def test_password_hashing(self):
        import bcrypt
        passwords = ["test123", "secure_pass!", "12345678"]
        for password in passwords:
            hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
            assert hashed != password
            assert bcrypt.checkpw(password.encode(), hashed.encode())
            assert not bcrypt.checkpw(b"wrong_password", hashed.encode())

    def test_jwt_contains_required_fields(self):
        import jwt
        import os
        payload = {"sub": "test@example.com", "role": "student", "user_id": 1}
        secret = "test_secret_key_123"
        token = jwt.encode(payload, secret, algorithm="HS256")
        decoded = jwt.decode(token, secret, algorithms=["HS256"])
        assert decoded["sub"] == "test@example.com"
        assert decoded["role"] == "student"
        assert decoded["user_id"] == 1


class TestItemKey:
    def test_item_key_format(self):
        from recommender import _item_key
        assert _item_key("course", 1) == "course_1"
        assert _item_key("book", 42) == "book_42"
        assert _item_key("article", 100) == "article_100"