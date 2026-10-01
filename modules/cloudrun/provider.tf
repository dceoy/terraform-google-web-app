provider "google" {
  project = var.project_id
  region  = var.region
  default_labels = {
    system-name = var.system_name
    env-type    = var.env_type
  }
}
