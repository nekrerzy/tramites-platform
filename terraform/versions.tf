# Un solo stack y un solo state, remoto en el bucket que crea este mismo código (state.tf).
# El primer apply corre con state local y luego se sube al bucket; para destruir se baja a
# local primero (ver README.md). El bucket se pasa en
# `terraform init -backend-config="bucket=<proyecto>-tfstate"` para no fijar un ID de proyecto
# en el repositorio.
terraform {
  required_version = ">= 1.11" # argumentos write-only (secrets.tf)

  backend "gcs" {
    prefix = "terraform"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.8"
    }
    # Genera la API key sin guardarla en el state (ephemeral random_password, secrets.tf).
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

  # Cobra la cuota de las APIs a este proyecto. Con credenciales de usuario (ADC) algunas APIs,
  # como la de presupuestos, rechazan la llamada si no se indica un proyecto de cuota.
  user_project_override = true
  billing_project       = var.project_id
}
