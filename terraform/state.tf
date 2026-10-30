# Bucket del state remoto de este mismo código. Como no existe antes del primer apply,
# el primer apply corre con state local y después el state se sube aquí (README.md).
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  # Permite que `terraform destroy` borre el bucket aunque tenga versiones de state (para entonces
  # el state ya se bajó a local).
  force_destroy = true

  # Versionado: permite recuperar un state anterior si algo sale mal.
  versioning {
    enabled = true
  }

  # Solo se conservan las 5 versiones anteriores más recientes de cada archivo.
  lifecycle_rule {
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.apis]
}
