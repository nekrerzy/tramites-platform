# Workload Identity Federation: GitHub Actions obtiene credenciales de corta duración con
# su token OIDC, sin llaves JSON.
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

locals {
  # Identidad federada de deploy.yml en main. El claim workflow_ref de GitHub tiene la forma
  # dueño/repo/.github/workflows/deploy.yml@refs/heads/main.
  deploy_principal = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.workflow_ref/${var.github_repo}/.github/workflows/deploy.yml@refs/heads/main"
}
