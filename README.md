# terraform-module-azure-container-app

Terraform module for [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/).

This module supports deploying **multiple container apps** within a single Container App Environment, allowing you to create microservices architectures or deploy multiple applications that share the same infrastructure.

## Features

- ✅ Deploy multiple container apps in a single environment
- ✅ Shared Container App Environment with custom workload profiles
- ✅ VNet integration support
- ✅ Key Vault secret integration
- ✅ Ingress configuration (external/internal)
- ✅ Custom scaling (min/max replicas)
- ✅ Azure Container Registry integration

## Examples

### Single Container App

Deploy a single container app:

```hcl
module "container_app" {
  source = "git@github.com:hmcts/terraform-module-azure-container-app?ref=main"

  product   = "myproduct"
  component = "nginx"
  env       = "dev"
  project   = "sds"

  common_tags = {
    environment = "dev"
  }

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  container_apps = {
    main = {
      containers = {
        nginx = {
          image  = "nginx:alpine"
          cpu    = 0.25
          memory = "0.5Gi"
          env    = []
        }
      }

      ingress_enabled     = true
      ingress_target_port = 80
      min_replicas        = 1
      max_replicas        = 3
    }
  }
}

# Access the FQDN
output "app_url" {
  value = "https://${module.container_app.container_app_fqdns["main"]}"
}
```

### Multiple Container Apps

Deploy multiple container apps (frontend, backend, worker) in a single environment:

```hcl
module "container_apps" {
  source = "git@github.com:hmcts/terraform-module-azure-container-app?ref=main"

  product   = "myproduct"
  component = "microservices"
  env       = "prod"
  project   = "cft"
  location  = "UK South"

  common_tags = {
    environment = "production"
    managedBy   = "terraform"
  }

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  subnet_id                  = azurerm_subnet.main.id

  container_apps = {
    # Frontend application
    frontend = {
      revision_mode = "Single"
      min_replicas  = 2
      max_replicas  = 10

      containers = {
        web = {
          image  = "myregistry.azurecr.io/frontend:latest"
          cpu    = 0.5
          memory = "1Gi"
          env = [
            {
              name  = "API_URL"
              value = "http://myproduct-microservices-backend-prod.internal"
            }
          ]
        }
      }

      ingress_enabled          = true
      ingress_external_enabled = true
      ingress_target_port      = 3000
      ingress_transport        = "http"
    }

    # Backend API
    backend = {
      revision_mode = "Single"
      min_replicas  = 3
      max_replicas  = 20

      containers = {
        api = {
          image  = "myregistry.azurecr.io/backend:latest"
          cpu    = 1.0
          memory = "2Gi"
          env = [
            {
              name        = "DB_PASSWORD"
              secret_name = "db-password"
            }
          ]
        }
      }

      key_vault_secrets = [
        {
          name                  = "db-password"
          key_vault_id          = azurerm_key_vault.main.id
          key_vault_secret_name = "database-password"
        }
      ]

      ingress_enabled          = true
      ingress_external_enabled = false  # Internal only
      ingress_target_port      = 8080
      ingress_transport        = "http"

      registry_server      = "myregistry.azurecr.io"
      registry_identity_id = azurerm_user_assigned_identity.acr.id
    }

    # Background worker (no ingress)
    worker = {
      revision_mode = "Single"
      min_replicas  = 1
      max_replicas  = 5

      containers = {
        processor = {
          image  = "myregistry.azurecr.io/worker:latest"
          cpu    = 0.5
          memory = "1Gi"
          env    = []
        }
      }

      ingress_enabled = false
    }
  }
}

# Access outputs
output "frontend_url" {
  value = "https://${module.container_apps.container_app_fqdns["frontend"]}"
}

output "all_app_names" {
  value = module.container_apps.container_app_names
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.70.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.70.0 |
| <a name="provider_azurerm.dns"></a> [azurerm.dns](#provider\_azurerm.dns) | >= 3.70.0 |
| <a name="provider_azurerm.private_dns"></a> [azurerm.private\_dns](#provider\_azurerm.private\_dns) | >= 3.70.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_container_app.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app) | resource |
| [azurerm_container_app_custom_domain.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_custom_domain) | resource |
| [azurerm_container_app_environment.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment) | resource |
| [azurerm_container_app_environment_certificate.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment_certificate) | resource |
| [azurerm_container_app_environment_storage.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment_storage) | resource |
| [azurerm_dns_txt_record.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_txt_record) | resource |
| [azurerm_management_lock.rg_lock](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_private_dns_a_record.private_a](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_user_assigned_identity.container_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_key_vault_secret.secrets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_resource_group.existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tag to be applied to resources | `map(string)` | n/a | yes |
| <a name="input_component"></a> [component](#input\_component) | https://hmcts.github.io/glossary/#component | `string` | n/a | yes |
| <a name="input_container_apps"></a> [container\_apps](#input\_container\_apps) | Map of container app configurations. Each key is the app name suffix. | <pre>map(object({<br/>    revision_mode         = optional(string, "Single")<br/>    min_replicas          = optional(number, 0)<br/>    max_replicas          = optional(number, 10)<br/>    workload_profile_name = optional(string)<br/>    containers = map(object({<br/>      image  = string<br/>      cpu    = number<br/>      memory = string<br/>      env = list(object({<br/>        name        = string<br/>        secret_name = optional(string)<br/>        value       = optional(string)<br/>      }))<br/>      volume_mounts = optional(map(object({<br/>        path     = string<br/>        sub_path = optional(string)<br/>      })), {})<br/>    }))<br/><br/>    volumes = optional(map(object({<br/>      storage_name  = string<br/>      storage_type  = string<br/>      mount_options = optional(string)<br/>    })), {})<br/><br/>    key_vault_secrets = optional(list(object({<br/>      name                  = string<br/>      key_vault_id          = string<br/>      key_vault_secret_name = string<br/>    })), [])<br/><br/>    registry_identity_id = optional(string)<br/>    registry_server      = optional(string)<br/><br/>    ingress_enabled                    = optional(bool, true)<br/>    ingress_external_enabled           = optional(bool, true)<br/>    ingress_target_port                = optional(number, 80)<br/>    ingress_exposed_port               = optional(number)<br/>    ingress_transport                  = optional(string, "auto")<br/>    ingress_allow_insecure_connections = optional(bool, false)<br/>    ingress_client_certificate_mode    = optional(string, "ignore")<br/>    ingress_additional_port_mappings = optional(list(object({<br/>      exposed_port = optional(number)<br/>      target_port  = number<br/>      external     = bool<br/>    })), [])<br/>    custom_domain = optional(object({<br/>      zone_name                   = string<br/>      zone_resource_group_name    = string<br/>      fqdn                        = string<br/>      environment_certificate_key = string<br/>      private_dns_zone = optional(object({<br/>        name                = string<br/>        resource_group_name = string<br/>      }))<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Environment value | `string` | n/a | yes |
| <a name="input_environment_certificates"></a> [environment\_certificates](#input\_environment\_certificates) | Map of Key Vault Secret IDs for certificates to be used in the Container App Environment. | `map(string)` | `{}` | no |
| <a name="input_environment_storage"></a> [environment\_storage](#input\_environment\_storage) | Map of storage accounts and shares for the Container App Environment. | <pre>map(object({<br/>    account_name = string<br/>    share_name   = string<br/>    access_key   = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_existing_resource_group_name"></a> [existing\_resource\_group\_name](#input\_existing\_resource\_group\_name) | Name of existing resource group to deploy resources into | `string` | `null` | no |
| <a name="input_internal_load_balancer_enabled"></a> [internal\_load\_balancer\_enabled](#input\_internal\_load\_balancer\_enabled) | Enable internal load balancer | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | Target Azure location to deploy the resource | `string` | `"UK South"` | no |
| <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id) | Log Analytics Workspace ID for Container App Environment | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The default name will be product+component+env, you can override the product+component part by setting this | `string` | `""` | no |
| <a name="input_product"></a> [product](#input\_product) | https://hmcts.github.io/glossary/#product | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name - sds or cft. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet ID for the Container App Environment | `string` | `null` | no |
| <a name="input_workload_profiles"></a> [workload\_profiles](#input\_workload\_profiles) | Map of workload profiles for the Container App Environment. | <pre>map(object({<br/>    workload_profile_type = string<br/>    minimum_count         = optional(number, 0)<br/>    maximum_count         = optional(number, 5)<br/>  }))</pre> | `{}` | no |
| <a name="input_zone_redundancy_enabled"></a> [zone\_redundancy\_enabled](#input\_zone\_redundancy\_enabled) | Enable zone redundancy | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_environment_static_ip_address"></a> [app\_environment\_static\_ip\_address](#output\_app\_environment\_static\_ip\_address) | The static IP address of the Container App Environment. This won't change unless the environment is re-created. |
| <a name="output_container_app_environment_id"></a> [container\_app\_environment\_id](#output\_container\_app\_environment\_id) | The ID of the Container App Environment |
| <a name="output_container_app_fqdns"></a> [container\_app\_fqdns](#output\_container\_app\_fqdns) | Map of container app names to their FQDNs (null if ingress not enabled) |
| <a name="output_container_app_identity_principal_id"></a> [container\_app\_identity\_principal\_id](#output\_container\_app\_identity\_principal\_id) | The Principal ID of the Container App's managed identity |
| <a name="output_container_app_ids"></a> [container\_app\_ids](#output\_container\_app\_ids) | Map of container app names to their IDs |
| <a name="output_container_app_names"></a> [container\_app\_names](#output\_container\_app\_names) | Map of container app keys to their names |
| <a name="output_resource_group_location"></a> [resource\_group\_location](#output\_resource\_group\_location) | The location of the resource group |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The name of the resource group |
<!-- END_TF_DOCS -->

## Contributing

We use pre-commit hooks for validating the terraform format and maintaining the documentation automatically.
Install it with:

```shell
brew install pre-commit terraform-docs
pre-commit install
```

If you add a new hook make sure to run it against all files:

```shell
pre-commit run --all-files
```

## Integration Tests

This directory contains integration tests for the Azure Container App Terraform module.

## Test Structure

- `test.tf` - Main test configuration that deploys an nginx container
- `modules/setup/` - Helper module that creates supporting infrastructure

## Running Tests Locally

### Prerequisites

- Terraform >= 1.5.0
- Azure CLI logged in
- Appropriate Azure permissions

### Run Tests

```bash
cd tests

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply (creates resources in Azure)
terraform apply

# Get the FQDN and test the nginx container
FQDN=$(terraform output -raw container_app_fqdn)
curl "https://$FQDN"

# Clean up
terraform destroy
```
