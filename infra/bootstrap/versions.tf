# Stack "bootstrap": lo aplica una persona una sola vez, con estado LOCAL (crea el bucket
# donde vivirá el estado remoto del stack principal). Se destruye al final de todo.
terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.8"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # La API de presupuestos (billingbudgets) exige un proyecto de cuota cuando se usan
  # credenciales de usuario (gcloud auth application-default login).
  user_project_override = true
  billing_project       = var.project_id
}
