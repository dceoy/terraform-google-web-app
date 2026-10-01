resource "google_project_service" "apis" {
  for_each                   = local.enabled_apis
  service                    = each.key
  project                    = local.project_id
  disable_on_destroy         = var.project_service_disable_on_destroy
  disable_dependent_services = var.project_service_disable_dependent_services
}

resource "google_artifact_registry_repository" "main" {
  count         = var.create_artifact_registry_repository ? 1 : 0
  depends_on    = [google_project_service.apis]
  project       = local.project_id
  location      = local.region
  repository_id = local.artifact_registry_repository_id
  description   = "Docker repository for ${var.system_name}-${var.env_type}"
  format        = "DOCKER"
  labels = {
    system-name = var.system_name
    env-type    = var.env_type
  }
}

resource "google_project_service_identity" "iap" {
  count      = var.iap_enabled ? 1 : 0
  provider   = google-beta
  depends_on = [google_project_service.apis]
  project    = local.project_id
  service    = "iap.googleapis.com"
}

resource "google_service_account" "main" {
  count        = var.create_service_account ? 1 : 0
  depends_on   = [google_project_service.apis]
  account_id   = "${var.system_name}-${var.env_type}-run-sa"
  display_name = "${var.system_name}-${var.env_type}-run-sa"
  description  = "Service account for the Cloud Run service"
  project      = local.project_id
}

resource "google_project_iam_member" "main" {
  # checkov:skip=CKV_GCP_41:Project role bindings are explicitly controlled via input variables.
  # checkov:skip=CKV_GCP_49:Project role bindings are explicitly controlled via input variables.
  for_each = toset(var.service_account_project_roles)
  member   = "serviceAccount:${local.service_account_email}"
  role     = each.value
  project  = local.project_id
}

resource "google_cloud_run_v2_service" "main" {
  depends_on          = [google_project_service.apis, google_project_iam_member.main, google_project_service_identity.iap]
  name                = local.service_name
  location            = local.region
  project             = local.project_id
  description         = "Cloud Run service for ${var.system_name}-${var.env_type}"
  ingress             = var.ingress
  launch_stage        = var.launch_stage
  deletion_protection = var.deletion_protection
  iap_enabled         = var.iap_enabled
  labels = {
    name        = local.service_name
    system-name = var.system_name
    env-type    = var.env_type
  }

  template {
    service_account                  = local.service_account_email
    timeout                          = "${var.timeout_seconds}s"
    execution_environment            = var.execution_environment
    max_instance_request_concurrency = var.max_instance_request_concurrency
    labels = {
      name        = local.service_name
      system-name = var.system_name
      env-type    = var.env_type
    }

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    dynamic "vpc_access" {
      for_each = var.vpc_access_connector != null ? [true] : []
      content {
        connector = var.vpc_access_connector
        egress    = var.vpc_access_egress
      }
    }

    containers {
      name    = var.container_name
      image   = var.image
      command = var.container_command
      args    = var.container_args

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle          = var.cpu_idle
        startup_cpu_boost = var.startup_cpu_boost
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    precondition {
      condition     = var.create_service_account || var.service_account_email != null
      error_message = "service_account_email is required when create_service_account is false."
    }
    precondition {
      condition     = var.max_instance_count >= var.min_instance_count
      error_message = "max_instance_count must be greater than or equal to min_instance_count."
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  # checkov:skip=CKV_GCP_102:Public access is opt-in via var.allow_unauthenticated.
  for_each = toset(concat(var.invoker_members, var.allow_unauthenticated ? ["allUsers"] : []))
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  member   = each.value
  role     = "roles/run.invoker"
}

resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  count    = var.iap_enabled ? 1 : 0
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  member   = google_project_service_identity.iap[0].member
  role     = "roles/run.invoker"
}
