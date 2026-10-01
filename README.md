# terraform-google-web-app

Terraform modules of serverless web applications on Google Cloud.

[![CI](https://github.com/dceoy/terraform-google-web-app/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/terraform-google-web-app/actions/workflows/ci.yml)

## Modules

| Module | Description |
| --- | --- |
| [`modules/cloudrun`](modules/cloudrun) | Cloud Run (v2) service with a dedicated service account, API enablement, and IAM invoker bindings |

## Installation

1.  Check out the repository.

    ```sh
    $ git clone https://github.com/dceoy/terraform-google-web-app.git
    $ cd terraform-google-web-app
    ```

2.  Install [Google Cloud SDK](https://cloud.google.com/sdk/docs) and authenticate.

3.  Install [Terraform](https://www.terraform.io/).

4.  Activate required Google Cloud APIs.

    ```sh
    $ PROJECT_ID='my-gcp-project-id'
    $ gcloud services enable \
        config.googleapis.com \
        cloudresourcemanager.googleapis.com \
        iam.googleapis.com \
        serviceusage.googleapis.com \
        run.googleapis.com \
        --project="${PROJECT_ID}"
    ```

5.  Create a Google Cloud service account for Infra Manager.

    ```sh
    $ SYSTEM_NAME='myapp'
    $ ENV_TYPE='dev'
    $ PROJECT_ID='my-gcp-project-id'
    $ LOCATION='us-central1'
    $ SERVICE_ACCOUNT_ID='my-infra-manager-sa'
    $ gcloud iam service-accounts create "${SERVICE_ACCOUNT_ID}" \
        --project="${PROJECT_ID}" \
        --display-name="${SERVICE_ACCOUNT_ID}"
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/config.admin'
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/storage.admin'
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/serviceusage.serviceUsageAdmin'
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/run.admin'
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/iam.serviceAccountAdmin'
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/iam.serviceAccountUser'
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/resourcemanager.projectIamAdmin'
    ```

6.  Create `envs/dev/terraform.tfvars` and set the variables as follows:

    ```hcl
    system_name = "myapp"
    env_type    = "dev"
    project_id  = "my-gcp-project-id"
    region      = "us-central1"
    image       = "us-docker.pkg.dev/my-gcp-project-id/my-repo/app:latest"

    # Optional: plain and Secret Manager environment variables
    env_vars = {
      LOG_LEVEL = "info"
    }
    secret_env_vars = {
      DB_PASSWORD = { secret = "my-db-password" }
    }

    # Optional: access control (the service is private by default)
    invoker_members       = ["serviceAccount:caller@my-gcp-project-id.iam.gserviceaccount.com"]
    allow_unauthenticated = false

    # Optional: set to false to allow the service to be destroyed
    deletion_protection = true
    ```

    The default `image` is Google's public hello container, so the module can be
    applied before an application image exists. To use `secret_env_vars`, add
    `secretmanager.googleapis.com` to `enabled_apis` and grant
    `roles/secretmanager.secretAccessor` to the service account through
    `service_account_project_roles`.

7.  Create a preview.

    ```sh
    $ PREVIEW_ID='my-preview-id'
    $ gcloud infra-manager previews create \
        "projects/${PROJECT_ID}/locations/${LOCATION}/previews/${PREVIEW_ID}" \
        --service-account="projects/${PROJECT_ID}/serviceAccounts/${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --inputs-file="envs/${ENV_TYPE}/terraform.tfvars" \
        --local-source='modules/cloudrun'
    $ gcloud infra-manager previews describe \
        "projects/${PROJECT_ID}/locations/${LOCATION}/previews/${PREVIEW_ID}"
    $ gcloud infra-manager previews delete \
        "projects/${PROJECT_ID}/locations/${LOCATION}/previews/${PREVIEW_ID}"
    ```

8.  Create or update a deployment.

    ```sh
    $ DEPLOYMENT_ID='my-deployment-id'
    $ gcloud infra-manager deployments apply \
        "projects/${PROJECT_ID}/locations/${LOCATION}/deployments/${DEPLOYMENT_ID}" \
        --service-account="projects/${PROJECT_ID}/serviceAccounts/${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --inputs-file="envs/${ENV_TYPE}/terraform.tfvars" \
        --import-existing-resources \
        --local-source='modules/cloudrun'
    $ gcloud infra-manager deployments describe \
        "projects/${PROJECT_ID}/locations/${LOCATION}/deployments/${DEPLOYMENT_ID}"
    ```

## Usage as a Terraform module

```hcl
module "cloudrun" {
  source = "github.com/dceoy/terraform-google-web-app//modules/cloudrun"

  system_name = "myapp"
  env_type    = "dev"
  project_id  = "my-gcp-project-id"
  region      = "us-central1"
  image       = "us-docker.pkg.dev/my-gcp-project-id/my-repo/app:latest"
}
```

## Cleanup

Set `deletion_protection = false` in the tfvars and apply it before deleting the
deployment, because the Cloud Run service is protected from deletion by default.

```sh
$ PROJECT_ID='my-gcp-project-id'
$ LOCATION='us-central1'
$ DEPLOYMENT_ID='my-deployment-id'
$ gcloud infra-manager deployments delete \
    "projects/${PROJECT_ID}/locations/${LOCATION}/deployments/${DEPLOYMENT_ID}"
```
