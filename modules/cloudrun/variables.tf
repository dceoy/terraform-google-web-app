variable "system_name" {
  description = "System name"
  type        = string
}

variable "env_type" {
  description = "Environment type"
  type        = string
}

variable "project_id" {
  description = "Project ID for Google Cloud resources"
  type        = string
  default     = null
}

variable "region" {
  description = "Region for Google Cloud resources"
  type        = string
  default     = null
}

variable "enabled_apis" {
  description = "List of Google Cloud APIs to enable"
  type        = list(string)
  default = [
    "run.googleapis.com",
    "iam.googleapis.com",
  ]
}

variable "project_service_disable_on_destroy" {
  description = "Whether to disable the Google Cloud APIs when the resources are destroyed"
  type        = bool
  default     = false
}

variable "project_service_disable_dependent_services" {
  description = "Whether to disable dependent services when the Google Cloud APIs are disabled"
  type        = bool
  default     = false
}

variable "image" {
  description = "Container image URL for the Cloud Run service"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "create_artifact_registry_repository" {
  description = "Whether to create an Artifact Registry Docker repository for application images"
  type        = bool
  default     = false
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID; defaults to <system_name>-<env_type> when repository creation is enabled"
  type        = string
  default     = null
}

variable "deploy_on_image_push" {
  description = "Whether to deploy a new Cloud Run revision when the configured Artifact Registry tag is pushed"
  type        = bool
  default     = false
}

variable "deploy_image_name" {
  description = "Artifact Registry image name monitored for automatic Cloud Run deployment"
  type        = string
  default     = "app"
}

variable "deploy_image_tag" {
  description = "Artifact Registry tag monitored for automatic Cloud Run deployment"
  type        = string
  default     = "prod"
}

variable "artifact_registry_notification_topic" {
  description = "Existing Artifact Registry notification topic resource name; when null and deploy_on_image_push is enabled, the module creates projects/<project>/topics/gcr"
  type        = string
  default     = null
}

variable "container_name" {
  description = "Container name"
  type        = string
  default     = "app"
}

variable "container_port" {
  description = "Port that the container listens on"
  type        = number
  default     = 8080
}

variable "container_command" {
  description = "Entrypoint command of the container (overrides the image ENTRYPOINT)"
  type        = list(string)
  default     = null
}

variable "container_args" {
  description = "Arguments of the container (overrides the image CMD)"
  type        = list(string)
  default     = null
}

variable "cpu_limit" {
  description = "CPU limit of the container"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit of the container"
  type        = string
  default     = "512Mi"
}

variable "cpu_idle" {
  description = "Whether to throttle CPU when no requests are being processed"
  type        = bool
  default     = true
}

variable "startup_cpu_boost" {
  description = "Whether to allocate extra CPU during container startup"
  type        = bool
  default     = false
}

variable "env_vars" {
  description = "Plain environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Environment variables sourced from Secret Manager secrets (map of variable name to secret ID and version)"
  type = map(object({
    secret  = string
    version = optional(string, "latest")
  }))
  default = {}
}

variable "min_instance_count" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
  validation {
    condition     = var.min_instance_count >= 0
    error_message = "Minimum instance count must be non-negative."
  }
}

variable "max_instance_count" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
  validation {
    condition     = var.max_instance_count >= 1
    error_message = "Maximum instance count must be at least 1."
  }
}

variable "max_instance_request_concurrency" {
  description = "Maximum number of concurrent requests per instance"
  type        = number
  default     = 80
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

variable "execution_environment" {
  description = "Execution environment of the revision"
  type        = string
  default     = "EXECUTION_ENVIRONMENT_GEN2"
  validation {
    condition     = contains(["EXECUTION_ENVIRONMENT_GEN1", "EXECUTION_ENVIRONMENT_GEN2"], var.execution_environment)
    error_message = "Execution environment must be EXECUTION_ENVIRONMENT_GEN1 or EXECUTION_ENVIRONMENT_GEN2."
  }
}

variable "ingress" {
  description = "Ingress setting of the Cloud Run service"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.ingress)
    error_message = "Ingress must be INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "launch_stage" {
  description = "Launch stage of the Cloud Run service"
  type        = string
  default     = "GA"
}

variable "deletion_protection" {
  description = "Whether to protect the Cloud Run service from deletion"
  type        = bool
  default     = true
}

variable "vpc_access_connector" {
  description = "Full resource name of the Serverless VPC Access connector (optional)"
  type        = string
  default     = null
}

variable "vpc_access_egress" {
  description = "Egress setting for the VPC access connector"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"
  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_access_egress)
    error_message = "VPC access egress must be ALL_TRAFFIC or PRIVATE_RANGES_ONLY."
  }
}

variable "create_service_account" {
  description = "Whether to create a dedicated service account for the Cloud Run service"
  type        = bool
  default     = true
}

variable "service_account_email" {
  description = "Email of an existing service account to run the service as (used when create_service_account is false)"
  type        = string
  default     = null
}

variable "service_account_project_roles" {
  description = "Project-level IAM roles granted to the Cloud Run service account (created or existing)"
  type        = list(string)
  default     = []
}

variable "iap_enabled" {
  description = "Whether to enable Identity-Aware Proxy for the Cloud Run service"
  type        = bool
  default     = false
}

variable "allow_unauthenticated" {
  description = "Whether to allow unauthenticated (public) invocations"
  type        = bool
  default     = false
}

variable "invoker_members" {
  description = "IAM members granted roles/run.invoker on the Cloud Run service"
  type        = list(string)
  default     = []
}
