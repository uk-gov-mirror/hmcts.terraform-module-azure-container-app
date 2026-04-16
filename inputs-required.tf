variable "env" {
  description = "Environment value"
  type        = string
}

variable "common_tags" {
  description = "Common tag to be applied to resources"
  type        = map(string)
}

variable "product" {
  description = "https://hmcts.github.io/glossary/#product"
  type        = string
}

variable "project" {
  description = "Project name - sds or cft."
  type        = string
}

variable "component" {
  description = "https://hmcts.github.io/glossary/#component"
  type        = string
}

variable "container_apps" {
  description = "Map of container app configurations. Each key is the app name suffix."
  type = map(object({
    revision_mode         = optional(string, "Single")
    min_replicas          = optional(number, 0)
    max_replicas          = optional(number, 10)
    workload_profile_name = optional(string)
    containers = map(object({
      image  = string
      cpu    = number
      memory = string
      env = list(object({
        name        = string
        secret_name = optional(string)
        value       = optional(string)
      }))
      volume_mounts = optional(map(object({
        path     = string
        sub_path = optional(string)
      })), {})
    }))

    volumes = optional(map(object({
      storage_name  = string
      storage_type  = string
      mount_options = optional(string)
    })), {})

    key_vault_secrets = optional(list(object({
      name                  = string
      key_vault_id          = string
      key_vault_secret_name = string
    })), [])

    registry_identity_id = optional(string)
    registry_server      = optional(string)

    ingress_enabled                    = optional(bool, true)
    ingress_external_enabled           = optional(bool, true)
    ingress_target_port                = optional(number, 80)
    ingress_transport                  = optional(string, "auto")
    ingress_allow_insecure_connections = optional(bool, false)
    ingress_client_certificate_mode    = optional(string)
    custom_domain = optional(object({
      zone_name                   = string
      zone_resource_group_name    = string
      fqdn                        = string
      environment_certificate_key = string
      private_dns_zone = optional(object({
        name                = string
        resource_group_name = string
      }))
    }))
  }))
}
