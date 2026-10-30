SHELL := /bin/bash
# Atajos para la app en local. Terraform no pasa por aquí: ver terraform/README.md.

IMAGE := tramites-api:local
# Puerto local; si está ocupado: make run-local PORT=8081
PORT ?= 8080

.PHONY: help test lint fmt docker-build run-local

help: ## Lista los comandos
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

test: ## Pruebas de la app
	uv run --directory app pytest -q

lint: ## Ruff: errores y formato (lo mismo que revisa ci)
	uv run --directory app ruff check .
	uv run --directory app ruff format --check .

fmt: ## Formatea el código de la app
	uv run --directory app ruff format .

docker-build: ## Construye la imagen local
	docker build --build-arg APP_VERSION=local -t $(IMAGE) app

run-local: docker-build ## Corre la imagen en localhost:PORT (8080) con las variables de .env
	@test -f .env || { echo "Falta .env: cp .env.example .env y completa API_KEY."; exit 1; }
	docker run --rm -p $(PORT):8080 --env-file .env $(IMAGE)
