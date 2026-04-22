resource "azurerm_user_assigned_identity" "container_app" {
  name                = "${local.name}-${var.env}-identity"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  tags                = local.tags
}

resource "azurerm_container_app_environment" "main" {
  name                               = "${local.name}-${var.env}-env"
  location                           = local.resource_group_location
  resource_group_name                = local.resource_group_name
  log_analytics_workspace_id         = var.log_analytics_workspace_id
  infrastructure_subnet_id           = var.subnet_id
  infrastructure_resource_group_name = "managed-${local.resource_group_name}"
  internal_load_balancer_enabled     = var.internal_load_balancer_enabled
  zone_redundancy_enabled            = var.zone_redundancy_enabled

  workload_profile {
    name                  = local.consumption_workload_profile_name
    workload_profile_type = "Consumption"
  }

  dynamic "workload_profile" {
    for_each = var.workload_profiles
    content {
      name                  = workload_profile.key
      workload_profile_type = workload_profile.value.workload_profile_type
      minimum_count         = lookup(workload_profile.value, "minimum_count", null)
      maximum_count         = lookup(workload_profile.value, "maximum_count", null)
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  tags = local.tags
}

resource "azurerm_container_app_environment_certificate" "this" {
  for_each                     = var.environment_certificates
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id

  certificate_key_vault {
    identity            = azurerm_user_assigned_identity.container_app.id
    key_vault_secret_id = each.value
  }

  tags = local.tags
}

resource "azurerm_container_app_environment_storage" "this" {
  for_each                     = var.environment_storage
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = each.value.account_name
  share_name                   = each.value.share_name
  access_key                   = try(each.value.access_key, null)
  access_mode                  = "ReadOnly"
}

resource "azurerm_container_app" "main" {
  for_each = var.container_apps

  name                         = "${local.name}-${each.key}-${var.env}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = local.resource_group_name
  revision_mode                = each.value.revision_mode
  workload_profile_name        = lookup(each.value, "workload_profile_name", local.consumption_workload_profile_name)
  tags                         = local.tags

  identity {
    type         = each.value.registry_identity_id != null ? "UserAssigned" : "SystemAssigned"
    identity_ids = each.value.registry_identity_id != null ? [each.value.registry_identity_id] : null
  }

  dynamic "registry" {
    for_each = each.value.registry_identity_id != null && each.value.registry_server != null ? [1] : []
    content {
      server   = each.value.registry_server
      identity = each.value.registry_identity_id
    }
  }

  template {
    min_replicas = each.value.min_replicas
    max_replicas = each.value.max_replicas

    dynamic "container" {
      for_each = each.value.containers
      content {
        name   = container.key
        image  = container.value.image
        cpu    = container.value.cpu
        memory = container.value.memory

        dynamic "env" {
          for_each = container.value.env
          content {
            name        = env.value.name
            secret_name = try(env.value.secret_name, null)
            value       = try(env.value.value, null)
          }
        }

        dynamic "volume_mounts" {
          for_each = try(container.value.volume_mounts, {})
          content {
            name     = volume_mounts.key
            path     = volume_mounts.value.path
            sub_path = volume_mounts.value.sub_path
          }
        }
      }
    }

    dynamic "volume" {
      for_each = each.value.volumes
      content {
        name          = volume.key
        storage_name  = volume.value.storage_name
        storage_type  = volume.value.storage_type
        mount_options = try(volume.value.mount_options, null)
      }
    }
  }

  dynamic "secret" {
    for_each = each.value.key_vault_secrets
    content {
      name  = secret.value.name
      value = data.azurerm_key_vault_secret.secrets["${each.key}-${secret.value.name}"].value
    }
  }

  dynamic "ingress" {
    for_each = each.value.ingress_enabled ? [1] : []
    content {
      external_enabled           = each.value.ingress_external_enabled
      target_port                = each.value.ingress_target_port
      transport                  = each.value.ingress_transport
      allow_insecure_connections = each.value.ingress_allow_insecure_connections
      client_certificate_mode    = each.value.ingress_transport == "tcp" ? null : each.value.ingress_client_certificate_mode

      traffic_weight {
        latest_revision = true
        percentage      = 100
      }

      dynamic "additional_port_mapping" {
        for_each = each.value.ingress_additional_port_mappings
        content {
          port         = additional_port_mapping.value.port
          external     = additional_port_mapping.value.external
          exposed_port = try(additional_port_mapping.value.exposed_port, null)
        }
      }
    }
  }
}

resource "azurerm_container_app_custom_domain" "this" {
  for_each                                 = { for k, v in var.container_apps : k => v if v.custom_domain != null }
  name                                     = each.value.custom_domain.fqdn
  container_app_id                         = azurerm_container_app.main[each.key].id
  container_app_environment_certificate_id = azurerm_container_app_environment_certificate.this[each.value.custom_domain.environment_certificate_key].id
  certificate_binding_type                 = "SniEnabled"
}

resource "azurerm_dns_txt_record" "this" {
  provider            = azurerm.dns
  for_each            = { for k, v in var.container_apps : k => v if v.custom_domain != null }
  name                = trimsuffix(each.value.custom_domain.fqdn, ".${each.value.custom_domain.zone_name}")
  resource_group_name = each.value.custom_domain.zone_resource_group_name
  zone_name           = each.value.custom_domain.zone_name
  ttl                 = 300

  record {
    value = azurerm_container_app.main[each.key].custom_domain_verification_id
  }
}

resource "azurerm_private_dns_a_record" "private_a" {
  provider            = azurerm.private_dns
  for_each            = { for k, v in var.container_apps : k => v if v.custom_domain != null && v.custom_domain.private_dns_zone != null }
  resource_group_name = each.value.custom_domain.private_dns_zone.resource_group_name
  zone_name           = each.value.custom_domain.private_dns_zone.name
  name                = trimsuffix(each.value.custom_domain.fqdn, ".${each.value.custom_domain.zone_name}")
  records             = [azurerm_container_app_environment.main.static_ip_address]
  ttl                 = 300
}
