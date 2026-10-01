data "google_client_config" "current" {}

locals {
  project_id                      = var.project_id != null ? var.project_id : data.google_client_config.current.project
  region                          = var.region != null ? var.region : data.google_client_config.current.region
  service_name                    = "${var.system_name}-${var.env_type}-cloud-run"
  artifact_registry_repository_id = coalesce(var.artifact_registry_repository_id, "${var.system_name}-${var.env_type}")
  enabled_apis = toset(concat(
    var.enabled_apis,
    var.iap_enabled ? ["iap.googleapis.com"] : [],
    var.create_artifact_registry_repository ? ["artifactregistry.googleapis.com"] : [],
  ))
  service_account_email = (
    var.create_service_account ? google_service_account.main[0].email : var.service_account_email
  )
}
