output "project_service_ids" {
  description = "List of enabled Google API service IDs"
  value       = [for svc in google_project_service.apis : svc.service]
}

output "artifact_registry_repository_name" {
  description = "Full resource name of the created Artifact Registry repository"
  value       = var.create_artifact_registry_repository ? google_artifact_registry_repository.main[0].name : null
}

output "artifact_registry_repository_url" {
  description = "Docker repository URL of the created Artifact Registry repository"
  value       = var.create_artifact_registry_repository ? "${local.region}-docker.pkg.dev/${local.project_id}/${local.artifact_registry_repository_id}" : null
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.name
}

output "cloud_run_service_id" {
  description = "Full resource ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.id
}

output "cloud_run_service_uri" {
  description = "URI of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.uri
}

output "cloud_run_latest_ready_revision" {
  description = "Name of the latest ready revision of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.latest_ready_revision
}

output "service_account_email" {
  description = "Email of the service account that the Cloud Run service runs as"
  value       = local.service_account_email
}


output "deploy_image_uri" {
  description = "Artifact Registry tag URI monitored for automatic Cloud Run deployment"
  value       = var.deploy_on_image_push ? local.deploy_image_uri : null
}

output "image_push_trigger_id" {
  description = "Cloud Build trigger ID for Artifact Registry image push deployment"
  value       = var.deploy_on_image_push ? google_cloudbuild_trigger.image_push[0].trigger_id : null
}

output "image_deployer_service_account_email" {
  description = "Service account used by Cloud Build for image push deployment"
  value       = var.deploy_on_image_push ? google_service_account.image_deployer[0].email : null
}

output "artifact_registry_notification_topic" {
  description = "Pub/Sub topic used for Artifact Registry notifications"
  value = var.deploy_on_image_push ? (
    var.artifact_registry_notification_topic != null
    ? var.artifact_registry_notification_topic
    : google_pubsub_topic.artifact_registry[0].id
  ) : null
}
