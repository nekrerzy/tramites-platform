# Alerta de presupuesto (obligatoria en la prueba). No corta el gasto: avisa por correo a
# los administradores de la cuenta de facturación al 50 %, 90 % y 100 % del monto, y cuando
# el pronóstico del mes supera el 100 %.
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "tramites-platform mensual"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.apis]
}
