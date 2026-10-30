# terraform/

Un stack y un state. El state vive en GCS, en el bucket que crea este mismo código
(`state.tf`). Las variables van en `terraform.tfvars` (copiar de `terraform.tfvars.example`).
Todos los comandos se corren desde esta carpeta con **tus** credenciales (`gcloud auth
application-default login`).

## Desde cero

El bucket del state no existe antes del primer apply, así que ese apply guarda el state en
local y después se sube al bucket. **Solo si el bucket todavía no existe**: si ya existe, ve a
"Clon nuevo".

```bash
# 1. Primer apply con state local: APIs, bucket y secreto (sin valor).
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
terraform init
terraform apply -target=google_storage_bucket.tfstate -target=google_secret_manager_secret.api_key

# 2. Subir el state al bucket y borrar la copia local (si se queda, podría subirse encima
#    del state remoto más adelante).
rm backend_override.tf
terraform init -migrate-state -force-copy -backend-config="bucket=<PROJECT_ID>-tfstate"
rm -f terraform.tfstate terraform.tfstate.backup

# 3. Valor del secreto: lo pide por teclado y nunca pasa por Terraform ni por el historial.
read -rsp "API_KEY: " v && echo && printf '%s' "$v" | gcloud secrets versions add tramites-api-key --data-file=-

# 4. Todo lo demás (Cloud Run, Artifact Registry, WIF, IAM, presupuesto).
terraform apply

# 5. Variables de GitHub Actions (nombres de recursos, no secretos).
terraform output -json github_variables \
  | python3 -c 'import json,sys; [print(k, v) for k, v in json.load(sys.stdin).items()]' \
  | while read -r k v; do gh variable set "$k" --body "$v"; done
```

## Clon nuevo

```bash
terraform init -backend-config="bucket=<PROJECT_ID>-tfstate"
```

## Destruir todo

El bucket se borra con todo lo demás, así que primero se baja el state a local.

```bash
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
terraform init -migrate-state -force-copy
terraform state list   # debe listar recursos; si sale vacío, falta el init de "Clon nuevo"
terraform destroy
rm backend_override.tf
```
