# syntax=docker/dockerfile:1
# Imagen multistage: la etapa "build" instala dependencias con uv; la final solo copia el
# entorno virtual y el código. Imágenes base fijadas por versión Y digest (nunca :latest).
# small change
FROM ghcr.io/astral-sh/uv:0.12.5@sha256:e85be844203885286c60ffad8a858d48afb6c5a5c237ca0e67f12e74b8f174b1 AS uv

FROM python:3.14.8-slim-trixie@sha256:fbecd461fc72d21b2143c6eaba25143738079154a6d0ea3da3aec724f50eed4a AS build
COPY --from=uv /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app
COPY pyproject.toml uv.lock ./
# --frozen: falla si uv.lock no coincide con pyproject.toml. Sin dependencias de desarrollo.
RUN uv sync --frozen --no-dev --no-install-project

FROM python:3.14.8-slim-trixie@sha256:fbecd461fc72d21b2143c6eaba25143738079154a6d0ea3da3aec724f50eed4a
# La versión se hornea en la imagen (no como env var de Cloud Run) para que cada despliegue
# no aparezca como drift en Terraform.
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PATH="/app/.venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1
# Usuario sin privilegios con UID fijo. pip no se usa en runtime (las dependencias vienen del
# .venv que arma uv) y trae dependencias propias con vulnerabilidades: se quita de la imagen.
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app \
    && python -m pip uninstall --yes --no-cache-dir pip
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
COPY tramites_api ./tramites_api
USER 10001
EXPOSE 8080
CMD ["uvicorn", "tramites_api.main:app", "--host", "0.0.0.0", "--port", "8080"]
