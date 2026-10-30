output "service_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "image_repository" {
  description = "Prefijo de las imágenes en Artifact Registry."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

# Variables de GitHub Actions (no son secretos: son nombres de recursos). README.md
# muestra cómo cargarlas con `gh variable set`.
output "github_variables" {
  value = {
    GCP_PROJECT_ID    = var.project_id
    GCP_REGION        = var.region
    GCP_WIF_PROVIDER  = google_iam_workload_identity_pool_provider.github.name
    GCP_DEPLOYER_SA   = google_service_account.deployer.email
    AR_REPOSITORY     = google_artifact_registry_repository.app.repository_id
    CLOUD_RUN_SERVICE = google_cloud_run_v2_service.api.name
  }
}
