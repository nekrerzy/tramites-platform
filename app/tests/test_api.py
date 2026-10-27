import pytest
from fastapi.testclient import TestClient

from tramites_api.main import app

API_KEY = "clave-de-prueba"


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("API_KEY", API_KEY)
    return TestClient(app)


def test_health_es_publico(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_tramite_existente(client):
    resp = client.get("/tramites/TRM-2026-000123", headers={"X-API-Key": API_KEY})
    assert resp.status_code == 200
    assert resp.json() == {
        "numero": "TRM-2026-000123",
        "tipo": "Pasaporte",
        "estado": "EN_REVISION",
    }


def test_tramite_inexistente_404(client):
    resp = client.get("/tramites/TRM-2026-999999", headers={"X-API-Key": API_KEY})
    assert resp.status_code == 404


def test_numero_invalido_422(client):
    resp = client.get("/tramites/no-es-un-numero", headers={"X-API-Key": API_KEY})
    assert resp.status_code == 422


@pytest.mark.parametrize("headers", [{}, {"X-API-Key": "incorrecta"}])
def test_sin_api_key_valida_401(client, headers):
    resp = client.get("/tramites/TRM-2026-000123", headers=headers)
    assert resp.status_code == 401


def test_sin_api_key_configurada_falla_cerrado(monkeypatch):
    monkeypatch.delenv("API_KEY", raising=False)
    resp = TestClient(app).get("/tramites/TRM-2026-000123", headers={"X-API-Key": "x"})
    assert resp.status_code == 503
