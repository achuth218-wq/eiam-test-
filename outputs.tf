output "control_plane_ids" {
  value = local.control_plane_ids
}

output "admin_api_urls" {
  value = { for name, id in local.control_plane_ids : name => "${var.konnect_server_url}/v2/control-planes/${id}/core-entities" }
}

output "proxy_urls" {
  description = "Data-plane proxy URLs of each control plane (if any are registered)."
  value       = { for name, ds in data.konnect_gateway_control_plane_list.cp : name => try(ds.data[0].config.proxy_urls, ds.data[0].proxy_urls, null) }
}

output "routes" {
  description = "API name -> route path to call on the data plane."
  value       = { for k, r in konnect_gateway_route.api : k => r.paths[0] }
}

output "service_ids" {
  value = { for k, s in konnect_gateway_service.api : k => s.id }
}
