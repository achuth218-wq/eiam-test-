terraform {
  required_version = ">= 1.10.0"

  required_providers {
    konnect = {
      source  = "kong/konnect"
      version = "~> 3.28"
    }
  }
}
