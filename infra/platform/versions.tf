# Stack principal. Estado remoto en el bucket que crea infra/bootstrap; el nombre del bucket
# se pasa en `terraform init -backend-config="bucket=<proyecto>-tfstate"` para no fijar un
# ID de proyecto en el repositorio.
terraform {
  required_version = ">= 1.9"

  backend "gcs" {
    prefix = "platform"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.8"
    }
    # Temporal: el estado aún tiene el random_id del key ring de KMS y Terraform necesita este
    # provider para destruirlo. Se quita después del apply.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    # Espera a que IAM propague el acceso al secreto antes de crear Cloud Run (cloud_run.tf).
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Cobra la cuota de las APIs a este proyecto. Con credenciales de usuario (ADC) algunas APIs
  # rechazan la llamada si no se indica un proyecto de cuota.
  user_project_override = true
  billing_project       = var.project_id
}
