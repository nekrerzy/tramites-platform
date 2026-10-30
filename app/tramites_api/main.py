"""API de consulta de estado de trámites.

Decisión de autenticación (explícita):
- GET /health es público a propósito: lo usan Cloud Run y el pipeline para verificar el
  despliegue y no expone datos.
- GET /tramites/{numero} exige la cabecera X-API-Key. El valor esperado llega en la variable
  de entorno API_KEY, que Cloud Run inyecta desde Secret Manager. Nunca se registra en logs.
"""

import os
import secrets
from typing import Annotated, Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Path, status
from pydantic import BaseModel

APP_VERSION = os.environ.get("APP_VERSION", "dev")

# Formato del número de trámite: TRM-AAAA-NNNNNN (ej. TRM-2026-000123).
NUMERO_PATTERN = r"^TRM-\d{4}-\d{6}$"

Estado = Literal["RECIBIDO", "EN_REVISION", "APROBADO", "RECHAZADO"]


class Tramite(BaseModel):
    numero: str
    tipo: str
    estado: Estado


# Datos de ejemplo en memoria: la prueba pide una app trivial, sin base de datos.
TRAMITES: dict[str, Tramite] = {
    t.numero: t
    for t in [
        Tramite(numero="TRM-2026-000123", tipo="Pasaporte", estado="EN_REVISION"),
        Tramite(numero="TRM-2026-000456", tipo="Licencia de conducir", estado="APROBADO"),
        Tramite(numero="TRM-2026-000789", tipo="Acta de nacimiento", estado="RECIBIDO"),
    ]
}

app = FastAPI(title="Trámites Ciudadanos", version=APP_VERSION)


def require_api_key(x_api_key: Annotated[str | None, Header()] = None) -> None:
    """Valida la cabecera X-API-Key contra API_KEY (comparación en tiempo constante)."""
    expected = os.environ.get("API_KEY")
    if not expected:
        # Falla cerrado: sin secreto configurado nadie consulta trámites.
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "API_KEY no configurada")
    if x_api_key is None or not secrets.compare_digest(x_api_key, expected):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "API key inválida")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": APP_VERSION}

@app.get("/hello")
def hello():
    return {"hello":"back"}

@app.get("/tramites/{numero}", dependencies=[Depends(require_api_key)])
def get_tramite(numero: Annotated[str, Path(pattern=NUMERO_PATTERN)]) -> Tramite:
    tramite = TRAMITES.get(numero)
    if tramite is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Trámite no encontrado")
    return tramite
