variable "project_id" {
  description = "ID del proyecto GCP personal."
  type        = string
}

variable "region" {
  description = "Región para el bucket de estado."
  type        = string
  default     = "us-central1"
}

variable "billing_account_id" {
  description = "Cuenta de facturación (XXXXXX-XXXXXX-XXXXXX) donde se crea la alerta de presupuesto."
  type        = string
}

variable "budget_currency" {
  description = "Moneda de la cuenta de facturación. Debe coincidir con la de la cuenta (USD, MXN, ...)."
  type        = string
  default     = "USD"
}

variable "budget_amount" {
  description = "Monto mensual del presupuesto, en budget_currency."
  type        = number
  default     = 10
}

variable "github_repo" {
  description = "Repositorio dueño/nombre. Solo sus workflows pueden autenticarse con WIF."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "Formato esperado: dueño/repositorio."
  }
}

variable "wif_pool_id" {
  description = "ID del Workload Identity Pool. Un pool borrado queda 30 días en soft-delete: si se recrea antes, usar otro ID."
  type        = string
  default     = "github"
}
