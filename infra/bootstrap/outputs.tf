output "state_bucket" {
  description = "Bucket del estado remoto de infra/platform."
  value       = google_storage_bucket.tfstate.name
}

output "workload_identity_provider" {
  description = "Nombre completo del proveedor OIDC (se usa en los workflows)."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "budget_id" {
  value = google_billing_budget.monthly.name
}
