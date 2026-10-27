resource "google_artifact_registry_repository" "app" {
  repository_id = "tramites"
  location      = var.region
  format        = "DOCKER"
  description   = "Imágenes de tramites-api publicadas por el pipeline."

  # Una etiqueta (ej. 0.1.0-abc1234) no puede reapuntar a otra imagen.
  docker_config {
    immutable_tags = true
  }

  # Limpieza para no pagar almacenamiento: se borran imágenes con más de 14 días, salvo las
  # 5 versiones más recientes (KEEP tiene prioridad sobre DELETE).
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "conservar-recientes"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
  cleanup_policies {
    id     = "borrar-antiguas"
    action = "DELETE"
    condition {
      older_than = "1209600s" # 14 días
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  repository = google_artifact_registry_repository.app.name
  location   = google_artifact_registry_repository.app.location
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.deployer.member
}
