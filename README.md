# terraform-google-web-app
Terraform modules of serverless web applications on Google Cloud

## Modules

| Module | Description |
| --- | --- |
| [`modules/cloud_run`](modules/cloud_run) | Cloud Run (v2) service with a dedicated service account, API enablement, and IAM invoker bindings |

## Usage

```hcl
module "cloud_run" {
  source = "./modules/cloud_run"

  system_name = "myapp"
  env_type    = "dev"
  project_id  = "my-gcp-project-id"
  region      = "us-central1"
  image       = "us-docker.pkg.dev/my-gcp-project-id/my-repo/app:latest"

  env_vars = {
    LOG_LEVEL = "info"
  }
  secret_env_vars = {
    DB_PASSWORD = { secret = "my-db-password" }
  }

  # Private by default; grant access explicitly
  invoker_members = ["serviceAccount:caller@my-gcp-project-id.iam.gserviceaccount.com"]
  # allow_unauthenticated = true  # make the service public

  # Set to false to allow `terraform destroy`
  deletion_protection = true
}
```

Notes:

- `secret_env_vars` references existing Secret Manager secrets. Grant the service account
  `roles/secretmanager.secretAccessor` via `service_account_project_roles`
  (and enable `secretmanager.googleapis.com` via `enabled_apis`).
- The default `image` is Google's public hello container so the module can be applied before an application image exists.
