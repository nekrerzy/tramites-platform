# Tres cuentas de servicio, cada una con lo mínimo:
#   runtime  -> identidad de Cloud Run; solo lee el secreto API_KEY.
#   deployer -> la usa deploy.yml; publica la imagen y despliega ese único servicio.
#   drift    -> la usa drift.yml; solo lectura para `terraform plan`.
# La infraestructura la aplica una persona desde su laptop (ver README, decisiones).

resource "google_service_account" "runtime" {
  account_id   = "tramites-runtime"
  display_name = "Cloud Run tramites-api (runtime)"
}

resource "google_service_account" "deployer" {
  account_id   = "gha-deployer"
  display_name = "GitHub Actions: deploy.yml"
}

resource "google_service_account" "drift" {
  account_id   = "gha-drift"
  display_name = "GitHub Actions: drift.yml (solo lectura)"
}

# --- Workload Identity Federation: cada workflow solo puede usar su propia cuenta ---

resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workflow_principal["deploy"]
}

resource "google_service_account_iam_member" "drift_wif" {
  service_account_id = google_service_account.drift.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.workflow_principal["drift"]
}

# --- deployer ---

# Puede desplegar revisiones que corran como la cuenta runtime (y solo esa).
resource "google_service_account_iam_member" "deployer_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer.member
}

# --- drift: solo lectura del proyecto y del estado ---

resource "google_project_iam_member" "drift_readonly" {
  for_each = toset([
    "roles/viewer",
    # Lectura de políticas IAM de cada recurso (los *_iam_member de este stack).
    "roles/iam.securityReviewer",
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.drift.member
}

resource "google_storage_bucket_iam_member" "drift_state_reader" {
  bucket = local.state_bucket
  role   = "roles/storage.objectViewer"
  member = google_service_account.drift.member
}
