# Kong Konnect APIs — Terraform

Deploys the APIs in [`apis.yaml`](apis.yaml) to the existing Konnect control plane
**`eapim-internal-dev`** (region **IN**, ID `9c2361e0-ca69-49f5-ab22-10e71f4c21aa`).
Each API becomes one **Gateway Service** (upstream URL) and one **Route** at `/<name>`
with `strip_path = true`. Example: `GET <proxy>/dog/breeds/list` → `https://dog.ceo/api/breeds/list`.

```
.
├── apis.yaml                     # the API catalogue — edit this to add/remove APIs
├── main.tf                       # control plane lookup, services, routes
├── variables.tf / terraform.tfvars   # region (IN) and control plane ID
├── versions.tf / provider.tf / backend.tf
├── outputs.tf
├── backend.hcl.example           # remote state settings for local runs
├── deploy.sh                     # local plan/apply/status/migrate helper (used by VS Code tasks)
├── scripts/smoke-test.sh         # calls every route through the data plane
├── .github/workflows/terraform.yml
├── .terraform.lock.hcl           # provider checksums for macOS, Linux (CI) and Windows
└── .vscode/                      # recommended extensions, format-on-save, tasks
```

## 1. One-time setup

### Remote state (required for GitHub Actions)
The workflow uses an **S3 backend**. Create an S3 bucket (versioning on) and an IAM role
that GitHub can assume via OIDC with `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`,
`s3:DeleteObject` on the bucket.
Not on AWS? Swap the block in [`backend.tf`](backend.tf) (azurerm / gcs / HCP Terraform)
and change the `Configure AWS credentials` + `Terraform init` steps in the workflow.

### Konnect token
Konnect → **Organization → System Accounts** → create one with *Control Plane Admin* on
`eapim-internal-dev` → generate a token (`spat_...`). A personal token (`kpat_...`) also works.

### GitHub repository settings
| Type | Name | Value |
|---|---|---|
| Secret | `KONNECT_TOKEN` | the `spat_`/`kpat_` token |
| Secret | `AWS_ROLE_ARN` | IAM role for the state bucket |
| Variable | `TF_STATE_BUCKET` | e.g. `my-terraform-state-bucket` |
| Variable | `TF_STATE_KEY` | `kong-konnect/eapim-internal-dev/terraform.tfstate` |
| Variable | `TF_STATE_REGION` | e.g. `ap-south-1` |

Create an **Environment** named `eapim-internal-dev` (Settings → Environments) and add
*Required reviewers* if applies should need a manual approval.

## 2. Pipeline behaviour
| Event | What runs |
|---|---|
| Pull request to `main` | fmt check → validate → plan, plan posted as a PR comment |
| Push / merge to `main` | plan → **apply** the same saved plan (only if there are changes) |
| Manual (*Actions → Run workflow*) | `plan` or `apply` |

### Move your existing local state to S3 (do this once, before the first pipeline run)
The 12 services and routes were already created from this laptop, so their state is in the
local `terraform.tfstate`. If the pipeline starts with an empty S3 state it will try to create
them again and fail on duplicate names. Move the state first:
```bash
cp backend.hcl.example backend.hcl     # fill in bucket / key / region (same as the GitHub variables)
./deploy.sh migrate                    # backs up terraform.tfstate, deletes backend_override.tf, copies state to S3
./deploy.sh plan                       # should say: No changes
```

## 3. Working locally in VS Code
1. Open the folder, accept the recommended extensions (Terraform, YAML, GitHub Actions).
   `.tf` files format on save.
2. **Terminal → Run Task** (or `Cmd+Shift+B` for the default deploy task):

| Task | What it does |
|---|---|
| Konnect: set token | Prompts for the token and saves it to `.env` (git-ignored) |
| Konnect: plan only | fmt → validate → plan |
| Konnect: deploy (plan → confirm → apply) | Plans, asks `y/N`, applies |
| Konnect: status | Lists managed resources and outputs |
| Konnect: smoke test | Calls every API through the data plane proxy URL you enter |
| Konnect: destroy | Deletes everything this project created (asks you to type `destroy`) |

The same commands work from a terminal: `./deploy.sh [plan|status|token|smoke <url>|migrate|destroy]`.
State comes from S3 via `backend.hcl`, or from the local file while `backend_override.tf` exists.
Once the pipeline is live, prefer PRs over local applies so every change goes through one place.

## 4. Adding an API
Add a line to `apis.yaml`, open a PR, review the plan comment, merge.
```yaml
- { name: myapi, control_plane: eapim-internal-dev, upstream: "https://api.example.com/v1" }
# optional: path: "/custom-path", tags: [team-x]
```

## 5. Already have these services in Konnect?
If services with the same names already exist (e.g. from decK), import them first or the
apply will fail on duplicate names:
```bash
terraform import 'konnect_gateway_service.api["dog"]' '{"control_plane_id":"9c2361e0-ca69-49f5-ab22-10e71f4c21aa","id":"<service-id>"}'
```

## 6. Smoke test
```bash
./scripts/smoke-test.sh https://<your-data-plane-proxy-url>
```
