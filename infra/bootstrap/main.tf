data "google_project" "this" {}

# APIs que usan los dos stacks. disable_on_destroy = false: deshabilitarlas al destruir no
# ahorra dinero y rompe destroys parciales; quedan habilitadas sin costo.
locals {
  apis = [
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)

  service            = each.value
  disable_on_destroy = false
}

# Bucket del estado remoto del stack infra/platform.
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  # Permite que `terraform destroy` borre el bucket aunque tenga versiones de estado.
  force_destroy = true

  # Versionado: permite recuperar un estado anterior si algo sale mal.
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

# Workload Identity Federation: GitHub Actions obtiene credenciales de corta duración con
# su token OIDC, sin llaves JSON. Qué cuenta de servicio puede usar cada workflow se decide
# en infra/platform (bindings por workflow_ref).
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.repository"   = "assertion.repository"
    "attribute.workflow_ref" = "assertion.workflow_ref"
  }

  # Ningún otro repositorio de GitHub puede siquiera intercambiar tokens en este pool.
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
