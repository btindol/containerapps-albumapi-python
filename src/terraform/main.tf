provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  default = "album-containerapps"
}

variable "location" {
  default = "canadacentral"
}

variable "environment_name" {
  default = "env-album-containerapps"
}

variable "api_name" {
  default = "album-api"
}

variable "frontend_name" {
  default = "album-ui"
}

variable "github_username" {
  default = "btindol"
}

variable "acr_name" {
  default = "acaalbumsbtindol"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Create container app environment
resource "azurerm_container_app_environment" "main" {
  name                = var.environment_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

# # Build and push Docker image
# resource "null_resource" "build_and_push_image" {
#   provisioner "local-exec" {
#     command = <<EOT
#       echo "Current working directory:"
#       cd
#       echo "Listing contents of working directory:"
#       dir
#       echo "Checking if Dockerfile exists:"
#       if exist Dockerfile (
#         echo "Dockerfile found"
#       ) else (
#         echo "Dockerfile not found"
#       )
#       echo "Running az acr build command"
#       az acr build --registry ${azurerm_container_registry.main.name} --image ${var.api_name}:latest .
#       echo "Build command completed"
#     EOT
#     working_dir = "C:\\temp\\python_container_app\\containerapps-albumapi-python\\src"  # Adjusted to full path
#   }
#   depends_on = [azurerm_container_registry.main]
# }

# # Deploy your image to container app
# resource "azurerm_container_app" "api" {
#   name                        = var.api_name
#   container_app_environment_id = azurerm_container_app_environment.main.id
#   resource_group_name         = azurerm_resource_group.main.name
#   revision_mode               = "Multiple"

#   ingress {
#     external_enabled = true
#     target_port      = 8080
#     traffic_weight {
#       percentage      = 100
#       latest_revision = true
#     }
#   }

#   template {
#     container {
#       name   = var.api_name
#       image  = "${azurerm_container_registry.main.login_server}/${var.api_name}:latest"
#       cpu    = "0.5"
#       memory = "1.0Gi"
#     }
#   }

#   identity {
#     type = "SystemAssigned"
#   }

#   depends_on = [null_resource.build_and_push_image]
# }

# Assign ACR Pull role to the container app
# resource "azurerm_role_assignment" "acr_pull" {
#   principal_id         = azurerm_container_app.api.identity[0].principal_id
#   role_definition_name = "AcrPull"
#   scope                = azurerm_container_registry.main.id
#   depends_on           = [azurerm_container_app.api]
# }

# # Output the FQDN of the container app
# output "app_fqdn" {
#   value = azurerm_container_app.api.latest_revision_fqdn
# }
