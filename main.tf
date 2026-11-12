locals {
  apis = {
    for api in yamldecode(file("${path.module}/${var.apis_file}")).apis :
    api.name => {
      control_plane = api.control_plane
      upstream      = api.upstream
      path          = try(api.path, "/${api.name}")
      tags          = concat(var.common_tags, try(api.tags, []), ["cp:${api.control_plane}"])

      # Split the upstream URL into the fields Konnect stores, so plan == what the API returns.
      protocol = regex("^(https?)://", api.upstream)[0]
      host     = regex("^https?://([^/:]+)", api.upstream)[0]
      port     = tonumber(try(regex("^https?://[^/:]+:([0-9]+)", api.upstream)[0], startswith(api.upstream, "https") ? 443 : 80))
      path_up  = try(regex("^https?://[^/]+(/.+)$", api.upstream)[0], null)
    }
  }

  control_plane_names = toset([for a in local.apis : a.control_plane])
}

# Look up each existing control plane by name (nothing is created here).
data "konnect_gateway_control_plane_list" "cp" {
  for_each = setsubtract(local.control_plane_names, keys(var.control_plane_ids))

  filter = {
    name = { eq = each.value }
  }
}

locals {
  control_plane_ids = merge(
    { for name, ds in data.konnect_gateway_control_plane_list.cp : name => one(ds.data[*].id) },
    var.control_plane_ids,
  )
}

resource "konnect_gateway_service" "api" {
  for_each = local.apis

  control_plane_id = local.control_plane_ids[each.value.control_plane]
  name             = each.key
  protocol         = each.value.protocol
  host             = each.value.host
  port             = each.value.port
  path             = each.value.path_up
  tags             = each.value.tags

  connect_timeout = 60000
  read_timeout    = 60000
  write_timeout   = 60000
  retries         = 5
  enabled         = true

  lifecycle {
    precondition {
      condition     = local.control_plane_ids[each.value.control_plane] != null
      error_message = "Control plane '${each.value.control_plane}' not found. Check the name and konnect_server_url region."
    }
  }
}

resource "konnect_gateway_route" "api" {
  for_each = local.apis

  control_plane_id = konnect_gateway_service.api[each.key].control_plane_id
  name             = "${each.key}-route"
  paths            = [each.value.path]
  protocols        = var.route_protocols
  strip_path       = true  # /dog/breeds/list -> https://dog.ceo/api/breeds/list
  preserve_host    = false # send upstream's own Host header (required for public APIs)
  tags             = each.value.tags

  service = {
    id = konnect_gateway_service.api[each.key].id
  }
}
