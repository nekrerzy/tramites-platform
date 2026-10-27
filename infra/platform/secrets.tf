# Terraform crea el secreto pero NO su valor: la versión se agrega a mano con
#   printf '%s' "$VALOR" | gcloud secrets versions add tramites-api-key --data-file=-
# Así el valor nunca queda en el estado de Terraform ni en git.
resource "google_secret_manager_secret" "api_key" {
  secret_id = "tramites-api-key"

  replication {
    auto {}
  }
}

# Solo la cuenta runtime puede leer este secreto (y ningún otro).
resource "google_secret_manager_secret_iam_member" "runtime_accessor" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime.member
}
