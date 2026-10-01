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

resource "google_project_service_identity" "cloudbuild" {
  count      = var.deploy_on_image_push ? 1 : 0
  provider   = google-beta
  depends_on = [google_project_service.apis]
  project    = local.project_id
  service    = "cloudbuild.googleapis.com"
}

resource "google_pubsub_topic" "artifact_registry" {
  count      = var.deploy_on_image_push && var.artifact_registry_notification_topic == null ? 1 : 0
  depends_on = [google_project_service.apis]
  project    = local.project_id
  name       = "gcr"
}

resource "google_service_account" "main" {
  count        = var.create_service_account ? 1 : 0
  depends_on   = [google_project_service.apis]
  account_id   = "${var.system_name}-${var.env_type}-run-sa"
  display_name = "${var.system_name}-${var.env_type}-run-sa"
  description  = "Service account for the Cloud Run service"
  project      = local.project_id
}

resource "google_service_account" "image_deployer" {
  count        = var.deploy_on_image_push ? 1 : 0
  depends_on   = [google_project_service.apis]
  account_id   = substr("${var.system_name}-${var.env_type}-deploy", 0, 30)
  display_name = "${var.system_name}-${var.env_type}-image-deployer"
  description  = "Service account for Artifact Registry image push deployments"
  project      = local.project_id
}

resource "google_project_iam_member" "image_deployer_cloudbuild" {
  for_each = var.deploy_on_image_push ? toset([
    "roles/cloudbuild.builds.builder",
    "roles/serviceusage.serviceUsageConsumer",
  ]) : toset([])
  project = local.project_id
  member  = "serviceAccount:${google_service_account.image_deployer[0].email}"
  role    = each.value
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

resource "google_cloud_run_v2_service_iam_member" "image_deployer" {
  count    = var.deploy_on_image_push ? 1 : 0
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  member   = "serviceAccount:${google_service_account.image_deployer[0].email}"
  role     = "roles/run.developer"
}

resource "google_service_account_iam_member" "image_deployer" {
  count              = var.deploy_on_image_push ? 1 : 0
  service_account_id = var.create_service_account ? google_service_account.main[0].name : "projects/${local.project_id}/serviceAccounts/${local.service_account_email}"
  member             = "serviceAccount:${google_service_account.image_deployer[0].email}"
  role               = "roles/iam.serviceAccountUser"
}

resource "google_artifact_registry_repository_iam_member" "image_deployer" {
  count      = var.deploy_on_image_push ? 1 : 0
  depends_on = [google_artifact_registry_repository.main]
  project    = local.project_id
  location   = local.region
  repository = local.artifact_registry_repository_id
  member     = "serviceAccount:${google_service_account.image_deployer[0].email}"
  role       = "roles/artifactregistry.reader"
}

resource "google_cloudbuild_trigger" "image_push" {
  count = var.deploy_on_image_push ? 1 : 0
  depends_on = [
    google_project_service_identity.cloudbuild,
    google_project_iam_member.image_deployer_cloudbuild,
    google_cloud_run_v2_service_iam_member.image_deployer,
    google_service_account_iam_member.image_deployer,
    google_artifact_registry_repository_iam_member.image_deployer,
  ]
  project         = local.project_id
  location        = local.region
  name            = substr("${local.service_name}-image-push", 0, 64)
  description     = "Deploy ${local.deploy_image_uri} to ${local.service_name} when the tag is pushed"
  service_account = google_service_account.image_deployer[0].name

  pubsub_config {
    topic = var.artifact_registry_notification_topic != null ? var.artifact_registry_notification_topic : google_pubsub_topic.artifact_registry[0].id
  }

  substitutions = {
    _ACTION = "$(body.message.data.action)"
    _TAG    = "$(body.message.data.tag)"
  }

  filter = "_ACTION == \"INSERT\" && _TAG == \"${local.deploy_image_uri}\""

  build {
    step {
      name       = "gcr.io/google.com/cloudsdktool/google-cloud-cli:stable"
      entrypoint = "gcloud"
      args = [
        "run",
        "deploy",
        local.service_name,
        "--image=${local.deploy_image_uri}",
        "--region=${local.region}",
        "--project=${local.project_id}",
        "--quiet",
      ]
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  lifecycle {
    precondition {
      condition     = var.image == local.deploy_image_uri
      error_message = "image must equal the monitored Artifact Registry tag URI when deploy_on_image_push is true."
    }
  }
}
