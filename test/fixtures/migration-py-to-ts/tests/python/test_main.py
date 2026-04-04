"""Tests for the Python API — must keep passing during migration."""
import pytest
from httpx import AsyncClient, ASGITransport
from src.python.main import app


@pytest.fixture
def client():
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


async def test_health(client):
    resp = await client.get("/api/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "healthy"


async def test_create_dataset(client):
    resp = await client.post("/api/datasets", json={
        "name": "test-data",
        "source_url": "https://example.com/data.csv",
        "format": "csv"
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "test-data"
    assert data["status"] == "pending"


async def test_list_datasets(client):
    resp = await client.get("/api/datasets")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
