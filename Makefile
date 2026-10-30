SHELL := /bin/bash
# Atajos para el flujo desde cero. Lee la configuración de .env (copiar de .env.example).
# Los comandos que tocan GCP o GitHub se ejecutan con TUS credenciales (gcloud/gh).
-include .env
export

TF_BOOTSTRAP := terraform -chdir=infra/bootstrap
TF_PLATFORM  := terraform -chdir=infra/platform
BOOTSTRAP_VARS := -var="project_id=$(PROJECT_ID)" -var="region=$(REGION)" \
	-var="billing_account_id=$(BILLING_ACCOUNT_ID)" -var="github_repo=$(GITHUB_REPO)" \
	-var="budget_currency=$(BUDGET_CURRENCY)" -var="budget_amount=$(BUDGET_AMOUNT)"
PLATFORM_VARS := -var="project_id=$(PROJECT_ID)" -var="region=$(REGION)" \
	-var="github_repo=$(GITHUB_REPO)"

.PHONY: help test lint docker-build run-local fmt validate bootstrap platform-init \
	platform-secret secret-version platform github-vars destroy

help: ## Lista los comandos
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

# --- Local (sin GCP) ---

test: ## Pruebas de la app
	uv run --directory app pytest -q

lint: ## Ruff + formato de Terraform
	uv run --directory app ruff check .
	uv run --directory app ruff format --check .
	terraform fmt -check -recursive infra

docker-build: ## Construye la imagen local
	docker build --build-arg APP_VERSION=local -t tramites-api:local app

run-local: docker-build ## Corre la imagen en http://localhost:8080 con API_KEY de .env
	docker run --rm -p 8080:8080 -e API_KEY="$(API_KEY)" tramites-api:local

fmt: ## Formatea Terraform
	terraform fmt -recursive infra

validate: ## terraform validate de ambos stacks (sin backend)
	$(TF_BOOTSTRAP) init -backend=false -input=false && $(TF_BOOTSTRAP) validate
	$(TF_PLATFORM) init -backend=false -input=false && $(TF_PLATFORM) validate

# --- Desde cero en GCP (en este orden) ---

bootstrap: ## 1. Bucket de estado, APIs, WIF y presupuesto (estado local)
	$(TF_BOOTSTRAP) init -input=false
	$(TF_BOOTSTRAP) apply $(BOOTSTRAP_VARS)

platform-init: ## 2. Conecta infra/platform con el bucket de estado
	$(TF_PLATFORM) init -input=false -reconfigure -backend-config="bucket=$(PROJECT_ID)-tfstate"

platform-secret: ## 3. Crea solo el secreto (sin valor)
	$(TF_PLATFORM) apply $(PLATFORM_VARS) -target=google_secret_manager_secret.api_key

secret-version: ## 4. Carga el valor de API_KEY en Secret Manager (lo pide por teclado)
	@read -rsp "Valor de API_KEY: " value && echo && \
		printf '%s' "$$value" | gcloud secrets versions add tramites-api-key \
		--project="$(PROJECT_ID)" --data-file=-

platform: ## 5. Resto de la plataforma (Cloud Run, AR, IAM)
	$(TF_PLATFORM) apply $(PLATFORM_VARS)

github-vars: ## 6. Carga las variables de GitHub Actions con gh
	$(TF_PLATFORM) output -json github_variables | python3 -c 'import json,sys; [print(k, v) for k, v in json.load(sys.stdin).items()]' | \
		while read -r name value; do gh variable set "$$name" --repo "$(GITHUB_REPO)" --body "$$value"; done

destroy: ## Destruye todo: primero platform, al final bootstrap
	$(TF_PLATFORM) destroy $(PLATFORM_VARS)
	$(TF_BOOTSTRAP) destroy $(BOOTSTRAP_VARS)
