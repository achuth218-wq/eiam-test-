variable "konnect_token" {
  description = "Konnect Personal Access Token (kpat_...) or System Account Token. Leave null to use the KONNECT_TOKEN env var."
  type        = string
  sensitive   = true
  default     = null
}

variable "konnect_server_url" {
  description = "Regional Konnect API URL where your control plane lives: us / eu / au / me / in (e.g. https://eu.api.konghq.com)."
  type        = string
  default     = "https://in.api.konghq.com"
}

variable "apis_file" {
  description = "YAML file listing the APIs to deploy."
  type        = string
  default     = "apis.yaml"
}

variable "common_tags" {
  description = "Tags added to every service and route."
  type        = list(string)
  default     = ["managed-by-terraform"]
}

variable "route_protocols" {
  description = "Protocols the routes accept."
  type        = list(string)
  default     = ["http", "https"]
}

variable "control_plane_ids" {
  description = "Optional map of control plane name -> ID. Names listed here skip the lookup by name."
  type        = map(string)
  default     = {}
}
