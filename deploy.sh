#!/usr/bin/env bash
# Local helper used by the VS Code tasks (Terminal → Run Task → "Konnect: ...").
#
#   ./deploy.sh            plan, ask for confirmation, apply
#   ./deploy.sh plan       plan only
#   ./deploy.sh status     list what Terraform manages + outputs
#   ./deploy.sh token      save your Konnect token to .env (git-ignored)
#   ./deploy.sh smoke URL  call every API through the data plane proxy
#   ./deploy.sh migrate    move local terraform.tfstate to the S3 backend (one time)
#   ./deploy.sh destroy    delete all services/routes this project created
#
# Backend selection:
#   backend_override.tf present -> local state (terraform.tfstate in this folder)
#   otherwise                   -> S3 using backend.hcl (copy backend.hcl.example)
set -euo pipefail
cd "$(dirname "$0")"

[[ -f .env ]] && set -a && source .env && set +a

need_token() {
  if [[ -z "${KONNECT_TOKEN:-}" ]]; then
    echo "KONNECT_TOKEN is not set. Run: ./deploy.sh token" >&2
    exit 1
  fi
}

tf_init() {
  if [[ -f backend_override.tf ]]; then
    terraform init -input=false >/dev/null
  elif [[ -f backend.hcl ]]; then
    terraform init -input=false -backend-config=backend.hcl >/dev/null
  else
    echo "No backend configured: create backend.hcl from backend.hcl.example (S3)," >&2
    echo "or create backend_override.tf with: terraform { backend \"local\" {} }" >&2
    exit 1
  fi
}

cmd="${1:-deploy}"
case "$cmd" in
  token)
    read -r -s -p "Konnect token (kpat_... or spat_...): " t; echo
    [[ -n "$t" ]] || { echo "empty token" >&2; exit 1; }
    umask 077
    printf 'KONNECT_TOKEN=%s\n' "$t" > .env
    echo "Saved to .env (git-ignored)."
    ;;
  plan)
    need_token; tf_init
    terraform fmt -recursive
    terraform validate
    terraform plan
    ;;
  deploy)
    need_token; tf_init
    terraform fmt -recursive
    terraform validate
    terraform plan -out=tfplan
    read -r -p "Apply this plan? [y/N] " ok
    [[ "$ok" =~ ^[Yy]$ ]] || { echo "Cancelled."; rm -f tfplan; exit 0; }
    terraform apply tfplan
    rm -f tfplan
    ;;
  status)
    need_token; tf_init
    terraform state list
    terraform output
    ;;
  smoke)
    ./scripts/smoke-test.sh "${2:?usage: ./deploy.sh smoke <proxy-url>}"
    ;;
  migrate)
    [[ -f backend.hcl ]] || { echo "Create backend.hcl first (cp backend.hcl.example backend.hcl)." >&2; exit 1; }
    [[ -f terraform.tfstate ]] || { echo "No local terraform.tfstate to migrate." >&2; exit 1; }
    cp terraform.tfstate "terraform.tfstate.pre-migrate.$(date +%Y%m%d%H%M%S)"
    rm -f backend_override.tf
    terraform init -input=false -migrate-state -force-copy -backend-config=backend.hcl
    echo "State is now in S3. Local backup kept as terraform.tfstate.pre-migrate.*"
    ;;
  destroy)
    need_token; tf_init
    terraform plan -destroy
    read -r -p "Type 'destroy' to delete these resources from Konnect: " ok
    [[ "$ok" == "destroy" ]] || { echo "Cancelled."; exit 0; }
    terraform destroy -auto-approve
    ;;
  *)
    sed -n '2,15p' "$0"; exit 1 ;;
esac
