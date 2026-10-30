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
# 1. Todo, con state local (el bucket del state todavía no existe).
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
terraform init
terraform apply

# 2. Subir el state al bucket y borrar la copia local (si se queda, podría subirse encima
#    del state remoto más adelante).
rm backend_override.tf
terraform init -migrate-state -force-copy -backend-config="bucket=<PROJECT_ID>-tfstate"
rm -f terraform.tfstate terraform.tfstate.backup

# 3. Variables de GitHub Actions (nombres de recursos, no secretos).
terraform output -json github_variables \
  | python3 -c 'import json,sys; [print(k, v) for k, v in json.load(sys.stdin).items()]' \
  | while read -r k v; do gh variable set "$k" --body "$v"; done
```

## API key

Terraform la genera en el apply sin guardarla en el state (`secrets.tf`).

```bash
gcloud secrets versions access latest --secret=tramites-api-key   # ver el valor
```

Rotar: subir `secret_data_wo_version` en `secrets.tf`, `terraform apply` y desplegar de nuevo
(Cloud Run lee `latest` al crear cada revisión).

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
