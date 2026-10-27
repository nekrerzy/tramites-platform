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
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
