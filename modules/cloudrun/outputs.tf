output "project_service_ids" {
  description = "List of enabled Google API service IDs"
  value       = [for svc in google_project_service.apis : svc.service]
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
