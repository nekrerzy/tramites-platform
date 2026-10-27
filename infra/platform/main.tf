data "google_project" "this" {}

locals {
  # Debe coincidir con el nombre que crea infra/bootstrap.
  state_bucket = "${var.project_id}-tfstate"

  wif_pool = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.wif_pool_id}"

  # Identidad federada de un workflow concreto en main. El claim workflow_ref de GitHub
  # tiene la forma dueño/repo/.github/workflows/archivo.yml@refs/heads/main.
  workflow_principal = {
    for wf in ["deploy", "drift"] :
    wf => "principalSet://iam.googleapis.com/${local.wif_pool}/attribute.workflow_ref/${var.github_repo}/.github/workflows/${wf}.yml@refs/heads/main"
  }
}
