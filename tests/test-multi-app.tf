terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias           = "dns"
  subscription_id = "ed302caf-ec27-4c64-a05e-85731c3ce90e"
  features {}
}

provider "azurerm" {
  alias           = "private_dns"
  subscription_id = "ed302caf-ec27-4c64-a05e-85731c3ce90e"
  features {}
}

# Test deploying multiple container apps in a single environment
module "multi_app_test" {
  source = "../"

  providers = {
    azurerm             = azurerm
    azurerm.dns         = azurerm.dns
    azurerm.private_dns = azurerm.private_dns
  }

  product   = "test"
  component = "multi"
  env       = "test"
  project   = "sds"
  location  = "UK South"

  common_tags = {
    environment = "test"
    project     = "multi-container-app-test"
    managedBy   = "terraform"
  }

  log_analytics_workspace_id = azurerm_log_analytics_workspace.test.id
  subnet_id                  = null

  # Deploy 3 container apps: frontend, backend, and worker
  container_apps = {
    frontend = {
      revision_mode = "Single"
      min_replicas  = 1
      max_replicas  = 3

      containers = {
        nginx = {
          image  = "nginx:alpine"
          cpu    = 0.25
          memory = "0.5Gi"
          env = [
            {
              name  = "BACKEND_URL"
              value = "http://test-multi-backend-test.internal"
            }
          ]
        }
      }

      ingress_enabled          = true
      ingress_external_enabled = true
      ingress_target_port      = 80
      ingress_transport        = "http"
    }

    backend = {
      revision_mode = "Single"
      min_replicas  = 1
      max_replicas  = 5

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

    worker = {
      revision_mode = "Single"
      min_replicas  = 0
      max_replicas  = 2

      containers = {
        processor = {
          image  = "busybox:latest"
          cpu    = 0.25
          memory = "0.5Gi"
          env = [
            {
              name  = "WORKER_MODE"
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
resource "azurerm_log_analytics_workspace" "test" {
  name                = "test-multi-test-law"
  location            = "UK South"
  resource_group_name = azurerm_resource_group.test.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "test"
    project     = "multi-container-app-test"
  }
}

resource "azurerm_resource_group" "test" {
  name     = "test-multi-test-rg"
  location = "UK South"

  tags = {
    environment = "test"
    project     = "multi-container-app-test"
  }
}

resource "azurerm_management_lock" "test_rg" {
  name       = "resource-group-lock"
  scope      = azurerm_resource_group.test.id
  lock_level = "CanNotDelete"
  notes      = "Prevent accidental deletion"
}

# Outputs to verify multi-app deployment
output "all_app_ids" {
  description = "IDs of all deployed container apps"
  value       = module.multi_app_test.container_app_ids
}

output "all_app_names" {
  description = "Names of all deployed container apps"
  value       = module.multi_app_test.container_app_names
}

output "all_app_fqdns" {
  description = "FQDNs of all deployed container apps (null for apps without ingress)"
  value       = module.multi_app_test.container_app_fqdns
}

output "frontend_fqdn" {
  description = "FQDN of the frontend app"
  value       = module.multi_app_test.container_app_fqdns["frontend"]
}

output "backend_fqdn" {
  description = "FQDN of the backend app (internal)"
  value       = module.multi_app_test.container_app_fqdns["backend"]
}

output "worker_fqdn" {
  description = "FQDN of the worker (should be null - no ingress)"
  value       = module.multi_app_test.container_app_fqdns["worker"]
}

output "container_app_environment_id" {
  description = "ID of the shared Container App Environment"
  value       = module.multi_app_test.container_app_environment_id
}

output "resource_group_name" {
  description = "Resource group where resources are deployed"
  value       = module.multi_app_test.resource_group_name
}
