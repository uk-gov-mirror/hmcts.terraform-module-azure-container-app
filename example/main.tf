# Example showing multiple container apps in a single environment
module "multi_container_apps" {
  source = "../"

  providers = {
    azurerm             = azurerm
    azurerm.dns         = azurerm.dns
    azurerm.private_dns = azurerm.private_dns
  }

  product   = "test"
  component = "multi"
  env       = var.env
  project   = "sds"
  location  = "UK South"

  common_tags = {
    environment = var.env
    project     = "container-app-multi-example"
    managedBy   = "terraform"
  }

  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
  subnet_id                  = null

  # Define multiple container apps
  container_apps = {
    # Frontend app
    frontend = {
      revision_mode = "Single"
      min_replicas  = 1
      max_replicas  = 5

      containers = {
        nginx = {
          image  = "nginx:alpine"
          cpu    = 0.25
          memory = "0.5Gi"
          env = [
            {
              name  = "BACKEND_URL"
              value = "http://test-multi-backend-${var.env}.internal"
            }
          ]
        }
      }

      ingress_enabled          = true
      ingress_external_enabled = true
      ingress_target_port      = 80
      ingress_transport        = "http"
    }

    # Backend API app
    backend = {
      revision_mode = "Single"
      min_replicas  = 2
      max_replicas  = 10

      containers = {
        api = {
          image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
          cpu    = 0.5
          memory = "1Gi"
          env = [
            {
              name  = "PORT"
              value = "8080"
            }
          ]
        }
      }

      ingress_enabled          = true
      ingress_external_enabled = false # Internal only
      ingress_target_port      = 8080
      ingress_transport        = "http"
    }

    # Worker/batch processing app (no ingress)
    worker = {
      revision_mode = "Single"
      min_replicas  = 1
      max_replicas  = 3

      containers = {
        processor = {
          image  = "busybox:latest"
          cpu    = 0.25
          memory = "0.5Gi"
          env = [
            {
              name  = "PROCESSING_MODE"
              value = "batch"
            }
          ]
        }
      }

      ingress_enabled = false # No ingress for worker
    }
  }
}

# Supporting resources
resource "azurerm_log_analytics_workspace" "example" {
  name                = "test-multi-${var.env}-law"
  location            = "UK South"
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = var.env
    project     = "container-app-multi-example"
  }
}

resource "azurerm_resource_group" "example" {
  name     = "test-multi-${var.env}-rg"
  location = "UK South"

  tags = {
    environment = var.env
    project     = "container-app-multi-example"
  }
}

resource "azurerm_management_lock" "example_rg" {
  name       = "resource-group-lock"
  scope      = azurerm_resource_group.example.id
  lock_level = "CanNotDelete"
  notes      = "Prevent accidental deletion"
}

# Output the FQDNs of the apps
output "frontend_fqdn" {
  value       = module.multi_container_apps.container_app_fqdns["frontend"]
  description = "Frontend app FQDN"
}

output "backend_fqdn" {
  value       = module.multi_container_apps.container_app_fqdns["backend"]
  description = "Backend app FQDN (internal)"
}

output "all_app_names" {
  value       = module.multi_container_apps.container_app_names
  description = "All container app names"
}
