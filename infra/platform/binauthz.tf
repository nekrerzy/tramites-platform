# Binary Authorization: Cloud Run solo admite imágenes con una atestación firmada por el
# pipeline. El pipeline firma el DIGEST de la imagen con una llave asimétrica de KMS; la
# política exige esa firma (attestor) para cualquier otra imagen.
#
# Ojo con destroy: en GCP los key rings y las llaves de KMS NO se borran. `terraform destroy`
# las quita del estado y programa la destrucción de las versiones (24 h); las versiones
# destruidas no cuestan. Por eso el key ring lleva sufijo aleatorio: al recrear el stack se
# crea uno nuevo en vez de chocar con el anterior.

resource "random_id" "kms_suffix" {
  byte_length = 2
}

resource "google_kms_key_ring" "binauthz" {
  name     = "binauthz-${random_id.kms_suffix.hex}"
  location = var.region
}

resource "google_kms_crypto_key" "attestor" {
  name     = "pipeline-attestor"
  key_ring = google_kms_key_ring.binauthz.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }

  # Mínimo permitido: tras un destroy la versión se destruye en 1 día.
  destroy_scheduled_duration = "86400s"
}

data "google_kms_crypto_key_version" "attestor" {
  crypto_key = google_kms_crypto_key.attestor.id
}

locals {
  kms_key_version = "${google_kms_crypto_key.attestor.id}/cryptoKeyVersions/${data.google_kms_crypto_key_version.attestor.version}"
}

# El attestor guarda sus atestaciones como "occurrences" de esta nota de Artifact Analysis.
resource "google_container_analysis_note" "attestor" {
  name = "pipeline-attestor-note"

  attestation_authority {
    hint {
      human_readable_name = "Imagen construida y firmada por deploy.yml"
    }
  }
}

resource "google_binary_authorization_attestor" "pipeline" {
  name        = "pipeline-attestor"
  description = "Firma del pipeline de GitHub Actions (deploy.yml)."

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor.name

    public_keys {
      id = data.google_kms_crypto_key_version.attestor.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.attestor.public_key[0].algorithm
      }
    }
  }
}

resource "google_binary_authorization_policy" "policy" {
  # Permite las imágenes de sistema que Google mantiene.
  global_policy_evaluation_mode = "ENABLE"

  # Única excepción: la imagen "hello" de Google con la que Terraform crea el servicio la
  # primera vez (antes de que exista una imagen firmada). Ver variable placeholder_image.
  admission_whitelist_patterns {
    name_pattern = "us-docker.pkg.dev/cloudrun/container/hello*"
  }

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.pipeline.id]
  }
}

# --- Quién firma y quién verifica ---

# El pipeline firma con la llave privada (que nunca sale de KMS)...
resource "google_kms_crypto_key_iam_member" "deployer_signer" {
  crypto_key_id = google_kms_crypto_key.attestor.id
  role          = "roles/cloudkms.signerVerifier"
  member        = google_service_account.deployer.member
}

# ...lee el attestor...
resource "google_binary_authorization_attestor_iam_member" "deployer_viewer" {
  attestor = google_binary_authorization_attestor.pipeline.name
  role     = "roles/binaryauthorization.attestorsViewer"
  member   = google_service_account.deployer.member
}

# ...y guarda la atestación como occurrence de la nota. Crear occurrences solo se puede
# otorgar a nivel proyecto; adjuntarlas se limita a esta nota.
resource "google_container_analysis_note_iam_member" "deployer_attacher" {
  note   = google_container_analysis_note.attestor.name
  role   = "roles/containeranalysis.notes.attacher"
  member = google_service_account.deployer.member
}

resource "google_project_iam_member" "deployer_occurrences" {
  project = var.project_id
  role    = "roles/containeranalysis.occurrences.editor"
  member  = google_service_account.deployer.member
}

# El agente de servicio de Binary Authorization lee las atestaciones al admitir una imagen.
resource "google_container_analysis_note_iam_member" "binauthz_agent_viewer" {
  note   = google_container_analysis_note.attestor.name
  role   = "roles/containeranalysis.notes.occurrences.viewer"
  member = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
}

# drift.yml necesita leer la llave pública para refrescar el data source del attestor.
resource "google_kms_crypto_key_iam_member" "drift_public_key" {
  crypto_key_id = google_kms_crypto_key.attestor.id
  role          = "roles/cloudkms.publicKeyViewer"
  member        = google_service_account.drift.member
}
