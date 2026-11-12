# Auth: set KONNECT_TOKEN in your shell (recommended) or pass var.konnect_token.
provider "konnect" {
  personal_access_token = var.konnect_token
  server_url            = var.konnect_server_url
}
