data "google_client_config" "current" {}

data "google_project" "current" {
  project_id = local.project_id
}

locals {
  project_id   = var.project_id != null ? var.project_id : data.google_client_config.current.project
  region       = var.region != null ? var.region : data.google_client_config.current.region
  service_name = "${var.system_name}-${var.env_type}-cloud-run"
  enabled_apis = toset(concat(
    var.enabled_apis,
    var.iap_enabled ? ["iap.googleapis.com"] : [],
  ))
  service_account_email = (
    var.create_service_account ? google_service_account.main[0].email : var.service_account_email
  )
}
