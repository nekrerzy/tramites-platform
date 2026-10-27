# Chuleta para la sesión en vivo

Variables que usan todos los comandos:

```bash
export PROJECT_ID=<proyecto> REGION=us-central1 SERVICE=tramites-api
export REPO=<usuario>/tramites-platform
gcloud config set project $PROJECT_ID
```

## Dónde encontrar cada cosa

| Qué | Consola | gcloud / gh |
|---|---|---|
| Logs de la app | Cloud Run → tramites-api → Logs | `gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="tramites-api"' --limit 20 --freshness 1h` |
| Revisiones y tráfico | Cloud Run → tramites-api → Revisiones | `gcloud run revisions list --service $SERVICE --region $REGION` |
| Imagen desplegada (digest) | Cloud Run → Revisión → Contenedor | `gcloud run services describe $SERVICE --region $REGION --format='value(spec.template.spec.containers[0].image)'` |
| Imágenes publicadas | Artifact Registry → tramites | `gcloud artifacts docker images list $REGION-docker.pkg.dev/$PROJECT_ID/tramites --include-tags` |
| IAM del proyecto | IAM y administración → IAM | `gcloud projects get-iam-policy $PROJECT_ID --flatten='bindings[].members' --format='table(bindings.role,bindings.members)'` |
| IAM del servicio | Cloud Run → tramites-api → Seguridad | `gcloud run services get-iam-policy $SERVICE --region $REGION` |
| Quién puede usar la cuenta de deploy (WIF) | IAM → Cuentas de servicio → gha-deployer → Principales | `gcloud iam service-accounts get-iam-policy gha-deployer@$PROJECT_ID.iam.gserviceaccount.com` |
| Proveedor WIF | IAM → Workload Identity Federation | `gcloud iam workload-identity-pools providers describe github-oidc --workload-identity-pool github --location global` |
| Audit logs (quién cambió qué) | Logging → Explorador de registros, filtro abajo | `gcloud logging read 'logName:"cloudaudit.googleapis.com%2Factivity"' --freshness 1d --limit 20 --format='table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName)'` |
| Secreto (metadatos, nunca el valor en pantalla) | Secret Manager → tramites-api-key | `gcloud secrets versions list tramites-api-key` |
| Costos | Facturación → Informes; Facturación → Presupuestos y alertas | `gcloud billing budgets list --billing-account <BILLING_ACCOUNT_ID>` |
| Política de Binary Authorization | Seguridad → Binary Authorization | `gcloud container binauthz policy export` |
| Attestor y atestaciones | Binary Authorization → Attestors | `gcloud container binauthz attestors list` / `gcloud beta container binauthz attestations list --attestor pipeline-attestor --attestor-project $PROJECT_ID` |
| Corridas de drift | GitHub → Actions → drift | `gh run list --workflow drift.yml --repo $REPO` / `gh issue list --label drift --repo $REPO` |
| Corridas de deploy | GitHub → Actions → deploy | `gh run list --workflow deploy.yml --repo $REPO` / `gh run view <id> --log` |

## Cambio de punta a punta (rama → PR → pipeline → deploy)

```bash
git checkout main && git pull
git checkout -b feature/DEVOPS-08-nuevo-tramite
# 1. Cambio: agregar un trámite en app/tramites_api/main.py (TRAMITES) y su prueba.
# 2. Subir la versión en app/pyproject.toml (0.1.0 -> 0.2.0); la etiqueta de la imagen sale de ahí.
uv run --directory app pytest -q && uv run --directory app ruff check .
git commit -am "feat(app): agregar trámite de ejemplo TRM-2026-001000"
git push -u origin feature/DEVOPS-08-nuevo-tramite
gh pr create --fill --base main
gh pr checks --watch                 # ci.yml en verde (obligatorio)
gh pr merge --merge --delete-branch
gh run watch $(gh run list --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')
URL=$(gcloud run services describe $SERVICE --region $REGION --format='value(status.url)')
curl $URL/health                     # "version": "0.2.0-<sha>"
```

Revertir un despliegue malo: `git revert` del merge en un PR (el pipeline redespliega la
versión anterior). Urgencia: `gcloud run services update-traffic $SERVICE --region $REGION --to-revisions <revision-anterior>=100`
y después el revert, para que `main` vuelva a describir lo que corre.

## Binary Authorization: imagen sin firma rechazada

```bash
# a) Imagen pública cualquiera
gcloud run deploy $SERVICE --region $REGION \
  --image us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
# b) Nuestra propia imagen, publicada sin pasar por el pipeline (sin atestación)
gcloud auth configure-docker $REGION-docker.pkg.dev
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/tramites/tramites-api:sin-firma-1 app
docker push $REGION-docker.pkg.dev/$PROJECT_ID/tramites/tramites-api:sin-firma-1
gcloud run deploy $SERVICE --region $REGION \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/tramites/tramites-api:sin-firma-1
```

Ambos fallan con un error de política de Binary Authorization ("not authorized by policy" /
"denied by attestor"); la revisión en curso sigue sirviendo. Evidencia en audit logs:

```bash
gcloud logging read 'protoPayload.serviceName="run.googleapis.com" AND severity>=ERROR' --freshness 1h --limit 5
```

Contraste: la imagen desplegada por el pipeline sí tiene atestación
(`gcloud beta container binauthz attestations list ...` de la tabla).

## Drift: provocarlo y detectarlo

```bash
# 1. "Alguien" cambia algo en la consola (o con gcloud):
gcloud run services update $SERVICE --region $REGION --max-instances 5
# 2. Correr la detección sin esperar el cron:
gh workflow run drift.yml --repo $REPO
gh run watch $(gh run list --workflow drift.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh issue list --label drift --repo $REPO      # issue con el plan: max_instance_count 5 -> 2
# 3. Corregir: volver al estado del código
make platform                                  # terraform apply (desde la laptop del operador)
```

Otros cambios que el drift detecta: quitar `allUsers` del invocador
(`gcloud run services remove-iam-policy-binding $SERVICE --region $REGION --member allUsers --role roles/run.invoker`),
cambiar memoria/CPU o agregar una variable de entorno. **No** cuenta como drift el cambio de
imagen: lo maneja el pipeline (`ignore_changes`).

## Si algo falla en vivo

- `deploy.yml` falla en `auth`: revisar variables (`gh variable list --repo $REPO`) y que el
  workflow corra en `main` (el binding WIF exige `deploy.yml@refs/heads/main`).
- `make platform` falla al crear Cloud Run con "permission denied" sobre el secreto: es la
  propagación de IAM (el binding `secretAccessor` se acaba de crear). Repetir `make platform`.
- `gcloud run deploy` del pipeline sin permiso: `gha-deployer` tiene lo que pide la doc de
  Cloud Run (`run.developer` sobre el servicio, `serviceAccountUser` sobre `tramites-runtime`,
  lectura del repo de AR). Revisar esos bindings y que el servicio no se haya recreado.
- `sign-and-create --validate` falla: revisar `attestorsVerifier` sobre el attestor y
  `signerVerifier` sobre la llave (`gcloud container binauthz attestors get-iam-policy pipeline-attestor`).
- Emergencia con Binary Authorization: despliegue con `--breakglass "justificación"` (queda
  en audit logs).
