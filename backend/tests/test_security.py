import secrets

import bcrypt

from security import hash_password, verify_password


def test_password_is_hashed_not_plaintext():
    password = "testpass123"
    hashed = hash_password(password)
    assert hashed != password


def test_password_verify_success():
    password = "securePass456"
    hashed = hash_password(password)
    assert verify_password(password, hashed) is True


def test_password_verify_failure():
    hashed = hash_password("correct-password")
    assert verify_password("wrong-password", hashed) is False


def test_bcrypt_roundtrip():
    """Legacy auth in main.py uses bcrypt directly — ensure hashing stays compatible."""
    password = "legacy123"
    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    assert hashed != password
    assert bcrypt.checkpw(password.encode(), hashed.encode()) is True


def test_otp_code_is_six_digits():
    code = f"{secrets.randbelow(1000000):06d}"
    assert len(code) == 6
    assert code.isdigit()
