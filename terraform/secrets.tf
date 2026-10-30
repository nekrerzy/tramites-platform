# Terraform genera el valor de la API key sin guardarlo: el password es efímero (existe solo
# durante el apply) y secret_data_wo es write-only (se envía a GCP, nunca al state ni al plan).
# Ver el valor: gcloud secrets versions access latest --secret=tramites-api-key
resource "google_secret_manager_secret" "api_key" {
  secret_id = "tramites-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

ephemeral "random_password" "api_key" {
  length  = 32
  special = false # cabe en una cabecera HTTP sin escapar nada
}

resource "google_secret_manager_secret_version" "api_key" {
  secret                 = google_secret_manager_secret.api_key.id
  secret_data_wo         = ephemeral.random_password.api_key.result
  secret_data_wo_version = 1 # rotar: subir este número y aplicar (luego un deploy nuevo)
}

# Solo la cuenta runtime puede leer este secreto (y ningún otro).
resource "google_secret_manager_secret_iam_member" "runtime_accessor" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime.member
}
