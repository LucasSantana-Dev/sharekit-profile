# Examples

## Examples

### 예시 1: Python FastAPI 테스트 (Pytest)

**상황**: FastAPI REST API 테스트

**사용자 요청**:
```
FastAPI로 만든 사용자 API를 pytest로 테스트해줘.
```

**최종 결과**:
```python
# tests/conftest.py
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import Base, get_db

# In-memory SQLite for tests
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            db_session.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()

# tests/test_auth.py
def test_register_user_success(client):
    response = client.post("/auth/register", json={
        "email": "test@example.com",
        "username": "testuser",
        "password": "Password123!"
    })

    assert response.status_code == 201
    assert "access_token" in response.json()
    assert response.json()["user"]["email"] == "test@example.com"

def test_register_duplicate_email(client):
    # First user
    client.post("/auth/register", json={
        "email": "test@example.com",
        "username": "user1",
        "password": "Password123!"
    })

    # Duplicate email
    response = client.post("/auth/register", json={
        "email": "test@example.com",
        "username": "user2",
        "password": "Password123!"
    })

    assert response.status_code == 409
    assert "already exists" in response.json()["detail"]

def test_login_success(client):
    # Register
    client.post("/auth/register", json={
        "email": "test@example.com",
        "username": "testuser",
        "password": "Password123!"
    })

    # Login
    response = client.post("/auth/login", json={
        "email": "test@example.com",
        "password": "Password123!"
    })

    assert response.status_code == 200
    assert "access_token" in response.json()

def test_protected_route_without_token(client):
    response = client.get("/auth/me")
    assert response.status_code == 401

def test_protected_route_with_token(client):
    # Register and get token
    register_response = client.post("/auth/register", json={
        "email": "test@example.com",
        "username": "testuser",
        "password": "Password123!"
    })
    token = register_response.json()["access_token"]

    # Access protected route
    response = client.get("/auth/me", headers={
        "Authorization": f"Bearer {token}"
    })

    assert response.status_code == 200
    assert response.json()["email"] == "test@example.com"
```
