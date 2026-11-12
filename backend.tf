# Remote state is REQUIRED for GitHub Actions: each runner is fresh, so local state
# would be lost and the next apply would try to recreate every service and route.
#
# Default: AWS S3 (partial config; bucket/key/region are passed at `terraform init`
# from GitHub repo variables, or from backend.hcl when you run it locally).
# Using something else? Replace this block with e.g.
#   backend "azurerm" {}    # Azure Storage
#   backend "gcs" {}        # Google Cloud Storage
#   cloud { organization = "my-org"  workspaces { name = "kong-konnect-apis" } }  # HCP Terraform
terraform {
  backend "s3" {}
}
