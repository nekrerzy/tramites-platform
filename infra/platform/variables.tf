variable "project_id" {
  description = "ID del proyecto GCP personal."
  type        = string
}

variable "region" {
  description = "Región de Cloud Run, Artifact Registry y KMS."
  type        = string
  default     = "us-central1"
}

variable "github_repo" {
  description = "Repositorio dueño/nombre (el mismo que en infra/bootstrap)."
  type        = string
}

variable "wif_pool_id" {
  description = "ID del Workload Identity Pool creado en infra/bootstrap."
  type        = string
  default     = "github"
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
