resource "google_cloud_run_v2_service" "api" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  # Sin protección: la prueba exige que todo se pueda destruir con `terraform destroy`.
  deletion_protection = false

  # Aplica la política de Binary Authorization del proyecto (binauthz.tf): solo corren
  # imágenes atestiguadas por el pipeline.
  binary_authorization {
    use_default = true
  }

  template {
    service_account = google_service_account.runtime.email

    # Escala a cero fuera de horario: sin tráfico no hay costo de cómputo.
    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    containers {
      image = var.placeholder_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true # CPU solo mientras se atiende una petición
      }

      # API_KEY llega desde Secret Manager como variable de entorno. "latest" toma la última
      # versión al crear cada revisión: rotar = agregar versión + nuevo despliegue.
      env {
        name = "API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  lifecycle {
    # La imagen la despliega el pipeline (por digest); Terraform maneja todo lo demás.
    # Sin esto, cada despliegue aparecería como drift. client/client_version los escribe gcloud.
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_secret_manager_secret_iam_member.runtime_accessor,
    google_binary_authorization_policy.policy,
  ]
}

# Acceso público (decisión explícita): los ciudadanos consultan sin cuenta de Google. El
# endpoint de trámites se protege en la app con X-API-Key; /health es público a propósito.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# El pipeline puede desplegar nuevas revisiones de ESTE servicio, no de otros.
resource "google_cloud_run_v2_service_iam_member" "deployer_developer" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.developer"
  member   = google_service_account.deployer.member
}
