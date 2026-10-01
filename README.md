# terraform-google-web-app

Terraform modules of serverless web applications on Google Cloud.

[![CI](https://github.com/dceoy/terraform-google-web-app/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/terraform-google-web-app/actions/workflows/ci.yml)

## Modules

| Module | Description |
| --- | --- |
| [`modules/cloudrun`](modules/cloudrun) | Cloud Run (v2) service with a dedicated service account, API enablement, optional Artifact Registry, CI-managed image deployment, optional IAP, and IAM invoker bindings |

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

    If the module should create an Artifact Registry repository, also grant:

    ```sh
    $ gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role='roles/artifactregistry.admin'
    ```

6.  Create `envs/dev/terraform.tfvars` and set the variables as follows:

    ```hcl
    system_name = "myapp"
    env_type    = "dev"
    project_id  = "my-gcp-project-id"
    region      = "us-central1"

    # Optional: create a Docker repository for application images.
    create_artifact_registry_repository = true
    artifact_registry_repository_id     = "myapp"

    # The image is used to bootstrap the Cloud Run service. Subsequent image
    # deployments are expected to be handled by CI/CD such as GitHub Actions.
    # image = "us-central1-docker.pkg.dev/my-gcp-project-id/myapp/app:<tag>"

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

    # Optional: protect the service with Cloud Run native IAP.
    # The IAP API, service identity, and roles/run.invoker grant are managed by
    # this module. IAP users and groups are intentionally not.
    iap_enabled = true

    # Optional: set to false to allow the service to be destroyed
    deletion_protection = true
    ```

    The default `image` is Google's public hello container, so the module can be
    applied before an application image exists. To use `secret_env_vars`, add
    `secretmanager.googleapis.com` to `enabled_apis` and grant
    `roles/secretmanager.secretAccessor` to the service account through
    `service_account_project_roles`.

    When `create_artifact_registry_repository = true`, the module enables
    `artifactregistry.googleapis.com` and creates a Docker repository in the
    Cloud Run region. Docker build and push are intentionally kept outside
    Terraform.

    When `iap_enabled = true`, the module enables `iap.googleapis.com`,
    explicitly provisions the Google-managed IAP service identity, and grants it
    `roles/run.invoker`. It does not manage
    `roles/iap.httpsResourceAccessor` memberships, so IAP users and groups can
    be changed independently of Terraform.

    If IAP is being enabled for the first time in a project that does not belong
    to a Google Cloud organization, Terraform cannot create the required OAuth
    client automatically. Enable IAP once in the Google Cloud Console or
    configure a custom OAuth client before relying on this Terraform-managed
    setup.

    For example:

    ```sh
    $ SERVICE_NAME='myapp-dev-cloud-run'
    $ USER_EMAIL='user@example.com'
    $ gcloud iap web add-iam-policy-binding \
        --member="user:${USER_EMAIL}" \
        --role='roles/iap.httpsResourceAccessor' \
        --region="${LOCATION}" \
        --resource-type='cloud-run' \
        --service="${SERVICE_NAME}" \
        --project="${PROJECT_ID}"
    ```

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

9.  Deploy application images from CI/CD. Terraform manages the Cloud Run service
    configuration, while the container image is intentionally deployment-owned.
    The module ignores external changes to the container image so a later
    Terraform apply does not roll back an image deployed by GitHub Actions.

    A GitHub Actions job can build, push, and immediately deploy the same
    immutable image:

    ```yaml
    - name: Build and push image
      run: |
        IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_ID}/app:${GITHUB_SHA}"
        gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
        docker build --tag "${IMAGE_URL}" .
        docker push "${IMAGE_URL}"
        echo "IMAGE_URL=${IMAGE_URL}" >> "${GITHUB_ENV}"

    - name: Deploy Cloud Run
      run: |
        gcloud run deploy "${SERVICE_NAME}" \
          --image="${IMAGE_URL}" \
          --region="${REGION}" \
          --project="${PROJECT_ID}" \
          --quiet
    ```

    Authenticate the workflow to Google Cloud before these steps, preferably
    with Workload Identity Federation. The workflow identity needs permission to
    push to the Artifact Registry repository, update the Cloud Run service, and
    act as the Cloud Run runtime service account. Keeping the image tag tied to
    `GITHUB_SHA` makes each deployed artifact immutable and traceable.

## Usage as a Terraform module

```hcl
module "cloudrun" {
  source = "github.com/dceoy/terraform-google-web-app//modules/cloudrun"

  system_name = "myapp"
  env_type    = "dev"
  project_id  = "my-gcp-project-id"
  region      = "us-central1"

  create_artifact_registry_repository = true
  artifact_registry_repository_id     = "myapp"

  # Bootstrap image only; CI/CD owns subsequent image deployments.
  image       = "us-docker.pkg.dev/cloudrun/container/hello"
  iap_enabled = true
}
```

The module outputs `artifact_registry_repository_url` and
`cloud_run_service_name`, which can be passed to GitHub Actions for build,
push, and deployment automation. Container image updates made by CI/CD are
excluded from Terraform drift reconciliation; other Cloud Run configuration
remains Terraform-managed.

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
