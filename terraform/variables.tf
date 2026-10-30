variable "project_id" {
  description = "ID del proyecto GCP personal."
  type        = string
}

variable "region" {
  description = "Región de Cloud Run, Artifact Registry y el bucket del state."
  type        = string
  default     = "us-central1"
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

variable "service_name" {
  description = "Nombre del servicio de Cloud Run."
  type        = string
  default     = "tramites-api"
}

variable "max_instances" {
  description = "Tope de instancias de Cloud Run: limita costo y abuso."
  type        = number
  default     = 2
}

variable "placeholder_image" {
  description = <<-EOT
    Imagen con la que Terraform crea el servicio la primera vez (todavía no existe la imagen
    de la app). Después el pipeline despliega la imagen real y Terraform ignora este campo.
  EOT
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello@sha256:d5dbac4a196296d8d517f8bdc302ad967deb9d83accf8bdbe491d3479e86a5e5"
}
