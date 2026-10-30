data "google_project" "this" {}

locals {
  wif_pool = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.wif_pool_id}"

  # Identidad federada de deploy.yml en main. El claim workflow_ref de GitHub tiene la forma
  # dueño/repo/.github/workflows/deploy.yml@refs/heads/main.
  deploy_principal = "principalSet://iam.googleapis.com/${local.wif_pool}/attribute.workflow_ref/${var.github_repo}/.github/workflows/deploy.yml@refs/heads/main"
}
