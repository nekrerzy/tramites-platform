SHELL := /bin/bash
# Atajos para el flujo desde cero. Lee la configuración de .env (copiar de .env.example).
# Los comandos que tocan GCP o GitHub se ejecutan con TUS credenciales (gcloud/gh).
-include .env
export

TF   := terraform -chdir=terraform
VARS := -var="project_id=$(PROJECT_ID)" -var="region=$(REGION)" \
	-var="billing_account_id=$(BILLING_ACCOUNT_ID)" -var="github_repo=$(GITHUB_REPO)" \
	-var="budget_currency=$(BUDGET_CURRENCY)" -var="budget_amount=$(BUDGET_AMOUNT)"
BUCKET := $(PROJECT_ID)-tfstate
# Mientras el bucket no existe (bootstrap) o está por borrarse (destroy), este archivo
# reemplaza el backend gcs por uno local. Terraform lee *_override.tf automáticamente.
LOCAL_BACKEND := terraform/backend_override.tf

.PHONY: help test lint docker-build run-local fmt validate bootstrap init secret-version \
	apply github-vars destroy

help: ## Lista los comandos
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

# --- Local (sin GCP) ---

test: ## Pruebas de la app
	uv run --directory app pytest -q

lint: ## Ruff + formato de Terraform
	uv run --directory app ruff check .
	uv run --directory app ruff format --check .
	terraform fmt -check -recursive terraform

docker-build: ## Construye la imagen local
	docker build --build-arg APP_VERSION=local -t tramites-api:local app

run-local: docker-build ## Corre la imagen en http://localhost:8080 con API_KEY de .env
	docker run --rm -p 8080:8080 -e API_KEY="$(API_KEY)" tramites-api:local

fmt: ## Formatea Terraform
	terraform fmt -recursive terraform

validate: ## terraform validate (sin backend)
	$(TF) init -backend=false -input=false && $(TF) validate

# --- Desde cero en GCP (en este orden) ---

bootstrap: ## 1. APIs, bucket del state y secreto (sin valor); al final sube el state al bucket
	@! gcloud storage buckets describe gs://$(BUCKET) >/dev/null 2>&1 || \
		{ echo "El bucket $(BUCKET) ya existe: usa 'make init' en lugar de bootstrap."; exit 1; }
	printf 'terraform {\n  backend "local" {}\n}\n' > $(LOCAL_BACKEND)
	$(TF) init -input=false -reconfigure
	$(TF) apply $(VARS) -target=google_storage_bucket.tfstate -target=google_secret_manager_secret.api_key
	rm $(LOCAL_BACKEND)
	$(TF) init -input=false -migrate-state -force-copy -backend-config="bucket=$(BUCKET)"
	@# La copia local ya está en el bucket; si se queda, un bootstrap futuro la subiría encima.
	rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup

init: ## Conecta con el state remoto (en un clon nuevo, después de bootstrap)
	$(TF) init -input=false -reconfigure -backend-config="bucket=$(BUCKET)"

secret-version: ## 2. Carga el valor de API_KEY en Secret Manager (lo pide por teclado)
	@read -rsp "Valor de API_KEY: " value && echo && \
		printf '%s' "$$value" | gcloud secrets versions add tramites-api-key \
		--project="$(PROJECT_ID)" --data-file=-

apply: ## 3. Todo lo demás (Cloud Run, AR, WIF, IAM, presupuesto)
	$(TF) apply $(VARS)

github-vars: ## 4. Carga las variables de GitHub Actions con gh
	$(TF) output -json github_variables | python3 -c 'import json,sys; [print(k, v) for k, v in json.load(sys.stdin).items()]' | \
		while read -r name value; do gh variable set "$$name" --repo "$(GITHUB_REPO)" --body "$$value"; done

destroy: ## Destruye todo: baja el state a local (el bucket también se borra) y destruye
	printf 'terraform {\n  backend "local" {}\n}\n' > $(LOCAL_BACKEND)
	$(TF) init -input=false -migrate-state -force-copy
	@# En un clon sin `make init` no hay nada que migrar: no reportar un destroy vacío como éxito.
	@$(TF) state list | grep -q . || \
		{ rm $(LOCAL_BACKEND); echo "State vacío: corre 'make init' primero."; exit 1; }
	$(TF) destroy $(VARS)
	rm $(LOCAL_BACKEND)
