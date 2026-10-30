# Dos cuentas de servicio, cada una con lo mínimo:
#   runtime  -> identidad de Cloud Run; solo lee el secreto API_KEY.
#   deployer -> la usa deploy.yml; publica la imagen y despliega ese único servicio.
# La infraestructura la aplica una persona desde su laptop (ver README, decisiones).

resource "google_service_account" "runtime" {
  account_id   = "tramites-runtime"
  display_name = "Cloud Run tramites-api (runtime)"

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "deployer" {
  account_id   = "gha-deployer"
  display_name = "GitHub Actions: deploy.yml"

  depends_on = [google_project_service.apis]
}

# --- Workload Identity Federation: solo deploy.yml en main puede usar la cuenta deployer ---

resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.deploy_principal
}

# --- deployer ---

# Puede desplegar revisiones que corran como la cuenta runtime (y solo esa).
resource "google_service_account_iam_member" "deployer_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer.member
}
