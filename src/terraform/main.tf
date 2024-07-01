variable "resource_group_name" {
  default = "album-containerappsz"
}

variable "acr_name" {
  default = "acaalbumsbtindolzz"
}

variable "location" {
  default = "canadacentral"
}

variable "environment_name" {
  default = "env-album-containerappsz"
}

variable "docker_image" {
  default = "flask-sample:latest"
}

variable "flask_repo_url" {
  default = "https://github.com/btindol/flask_template.git"
}

variable "static_web_app_name" {
  default = "album-static-web-appz"
}

variable "repo_url" {
  default = "https://github.com/btindol/nextjs-template.git"
}

variable "app_location" {
  default = "/"
}

variable "output_location" {
  default = "out"
}

variable "api_location" {
  default = "api"
}

variable "ghub_token" {
  description = "GitHub Token"
  type        = string
  sensitive   = true
}

variable "static_web_app_location" {
  default = "eastus2"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "main" {
  depends_on          = [azurerm_resource_group.main]
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "null_resource" "build_and_push_docker_image" {
  depends_on = [azurerm_container_registry.main]

  provisioner "local-exec" {
    command = <<EOT
      $ErrorActionPreference = "Stop"

      $env:ACR_NAME = "${azurerm_container_registry.main.name}"
      $env:ACR_LOGIN_SERVER = "${azurerm_container_registry.main.login_server}"
      $env:FLASK_REPO_URL = "${var.flask_repo_url}"

      # Clone the Flask repository
      git clone $env:FLASK_REPO_URL flask_repo
      cd flask_repo

      # Build the Docker image
      docker build -t $env:ACR_LOGIN_SERVER/${var.docker_image} .

      # Log in to ACR
      az acr login --name $env:ACR_NAME

      # Push the Docker image to ACR
      docker push $env:ACR_LOGIN_SERVER/${var.docker_image}

      # Clean up
      cd ..
      Remove-Item -Recurse -Force flask_repo
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

resource "azurerm_container_app_environment" "main" {
  depends_on          = [azurerm_resource_group.main]
  name                = var.environment_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

resource "time_sleep" "wait_for_resource_group" {
  depends_on = [azurerm_resource_group.main]
  create_duration = "30s"
}

resource "azurerm_user_assigned_identity" "container_app_identity" {
  depends_on = [time_sleep.wait_for_resource_group]
  name                = "container-app-identityz"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "acr_pull_role" {
  depends_on = [
    azurerm_container_registry.main,
    azurerm_user_assigned_identity.container_app_identity
  ]
  principal_id         = azurerm_user_assigned_identity.container_app_identity.principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.main.id
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [azurerm_role_assignment.acr_pull_role]
  create_duration = "60s"
}

resource "azurerm_container_app" "main" {
  depends_on = [
    null_resource.build_and_push_docker_image,
    azurerm_role_assignment.acr_pull_role,
    time_sleep.wait_60_seconds
  ]
  name                         = "flask-app"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.main.id

  identity {
    type = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app_identity.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.container_app_identity.id
  }

  template {
    container {
      name   = "flask-container"
      image  = "${azurerm_container_registry.main.login_server}/${var.docker_image}"
      cpu    = "0.5"
      memory = "1.0Gi"

      env {
        name  = "PORT"
        value = "8080" # Ensure this matches the Dockerfile port
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  revision_mode = "Single"
}

resource "null_resource" "deploy_static_web_app" {
  depends_on = [azurerm_container_app.main]

  provisioner "local-exec" {
    command = <<EOT
      $ErrorActionPreference = "Stop"

      $env:STATIC_WEB_APP_NAME = "${var.static_web_app_name}"
      $env:RESOURCE_GROUP_NAME = "${var.resource_group_name}"
      $env:STATIC_WEB_APP_LOCATION = "${var.static_web_app_location}"
      $env:REPO_URL = "${var.repo_url}"
      $env:APP_LOCATION = "${var.app_location}"
      $env:OUTPUT_LOCATION = "${var.output_location}"
      $env:API_LOCATION = "${var.api_location}"
      $env:GHUB_TOKEN = "${var.ghub_token}"

      # Create the Azure Static Web App
      az staticwebapp create `
        --name $env:STATIC_WEB_APP_NAME `
        --resource-group $env:RESOURCE_GROUP_NAME `
        --location $env:STATIC_WEB_APP_LOCATION `
        --source $env:REPO_URL `
        --app-location $env:APP_LOCATION `
        --output-location $env:OUTPUT_LOCATION `
        --api-location $env:API_LOCATION `
        --branch main `
        --token $env:GHUB_TOKEN

      # Generate and retrieve the Static Web App URL
      $SWA_URL = az staticwebapp show `
        --name $env:STATIC_WEB_APP_NAME `
        --resource-group $env:RESOURCE_GROUP_NAME `
        --query "defaultHostname" `
        --output tsv

      # Generate and retrieve the Static Web App API token
      $SWA_API_TOKEN = az staticwebapp secrets list `
        --name $env:STATIC_WEB_APP_NAME `
        --resource-group $env:RESOURCE_GROUP_NAME `
        --query "properties.apiKey" `
        --output tsv

      echo $SWA_URL > ${path.module}/static_web_app_url.txt
      echo $SWA_API_TOKEN > ${path.module}/static_web_app_token.txt
      echo "Static Web App URL: https://$SWA_URL"
      echo "Static Web App Token: $SWA_API_TOKEN"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

resource "null_resource" "read_static_web_app_info" {
  depends_on = [null_resource.deploy_static_web_app]

  provisioner "local-exec" {
    command = <<EOT
      $static_web_app_url = Get-Content -Path "${path.module}/static_web_app_url.txt"
      $static_web_app_token = Get-Content -Path "${path.module}/static_web_app_token.txt"
      echo "Static Web App URL (from file): $static_web_app_url"
      echo "Static Web App Token (from file): $static_web_app_token"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

data "local_file" "static_web_app_url_file" {
  filename = "${path.module}/static_web_app_url.txt"
}

data "local_file" "static_web_app_token_file" {
  filename = "${path.module}/static_web_app_token.txt"
}
locals {  
  # Read the URL and ensure it's properly formatted with the https:// scheme  
  raw_static_web_app_url = trimspace(data.local_file.static_web_app_url_file.content)  
  # Ensure that the URL does not contain any unwanted characters and is a valid URL  
  # Prepend the https:// scheme to the URL  
  static_web_app_url = "https://${replace(local.raw_static_web_app_url, "/[^a-zA-Z0-9-._~:/?#[\\]@!$&'()*+,;=]/", "")}"  
  static_web_app_token = trimspace(replace(data.local_file.static_web_app_token_file.content, "�", ""))
}

output "static_web_app_url" {
  value = local.static_web_app_url
}

output "static_web_app_url_debug" {
  value = "Static Web App URL: ${local.static_web_app_url}"
}

output "static_web_app_token" {
  value     = local.static_web_app_token
  sensitive = true
}

output "static_web_app_token_debug" {
  value = "Static Web App Token: ${local.static_web_app_token}"
}

# Update references in the API Management policy

#################################################################################################################################################
variable "api_name" {
  default = "album-api"
}

variable "frontend_name" {
  default = "album-ui"
}

variable "github_username" {
  default = "btindol"
}

variable "apim_name" {
  default = "album-apim"
}

variable "apim_api_name" {
  default = "album-api"
}

variable "apim_product_name" {
  default = "album-product"
}

data "azurerm_client_config" "example" {}

# API Management
resource "azurerm_api_management" "apim" {
  depends_on = [azuread_service_principal.nextjs_sp]  # Add this line
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "My Company"
  publisher_email     = "company@terraform.io"
  sku_name            = "Developer_1"  # Use Developer SKU for non-production environments

  timeouts {
    create = "4h"  # Increase the timeout to 2 hours
  }
}

# API Management Backend
resource "azurerm_api_management_backend" "example_backend" {
  depends_on = [azurerm_api_management.apim]  # Change dependency
  name                = "example-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = azurerm_container_app.main.latest_revision_fqdn
}

# API Management API
resource "azurerm_api_management_api" "apim_api" {
  depends_on = [azurerm_api_management.apim]  # Change dependency
  name                = var.apim_api_name
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Album API"
  path                = "albums"
  protocols           = ["https"]
}

# API Management API Operation
resource "azurerm_api_management_api_operation" "apim_api_operation" {
  depends_on = [azurerm_api_management_api.apim_api]  # Change dependency
  operation_id        = "getAlbums"
  api_name            = azurerm_api_management_api.apim_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  display_name        = "Get Albums"
  method              = "GET"
  url_template        = "/albums"
  description         = "Request to get albums"

  request {
    description = "Request to get albums"
    query_parameter {
      name     = "name"
      required = false
      type     = "string"
    }
  }

  response {
    status_code = 200
    description = "Successful operation"
  }
}

# API Management API Operation Policy
resource "azurerm_api_management_api_operation_policy" "apim_api_operation_policy" {
  depends_on = [azurerm_api_management_api_operation.apim_api_operation]  # Change dependency
  operation_id        = azurerm_api_management_api_operation.apim_api_operation.operation_id
  api_name            = azurerm_api_management_api.apim_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  xml_content         = <<XML
<policies>
    <inbound>
        <set-header name="Access-Control-Allow-Origin" exists-action="override">
            <value>${local.static_web_app_url}</value>
        </set-header>
        <set-header name="Access-Control-Allow-Methods" exists-action="override">
            <value>GET, OPTIONS</value>
        </set-header>
        <set-header name="Access-Control-Allow-Headers" exists-action="override">
            <value>Content-Type, Authorization, Ocp-Apim-Subscription-Key</value>
        </set-header>
        <set-backend-service base-url="${azurerm_container_app.main.latest_revision_fqdn}" />
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

# API Management API Product
resource "azurerm_api_management_product" "apim_product" {
  depends_on = [azurerm_api_management.apim]  # Change dependency
  product_id          = var.apim_product_name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  display_name        = "Album Product"
  approval_required   = false
  subscription_required = true
  published           = true
}

# API Management Product API Link
resource "azurerm_api_management_product_api" "apim_product_api" {
  depends_on = [azurerm_api_management_api.apim_api]  # Change dependency
  api_name            = azurerm_api_management_api.apim_api.name
  product_id          = azurerm_api_management_product.apim_product.product_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
}


# Output the URL of the API Management instance
output "apim_url" {
  value = azurerm_api_management.apim.gateway_url
}

# Azure AD App registration
resource "random_password" "nextjs_app_password" {
  length  = 16
  special = true
}

data "azuread_client_config" "current" {}

# Azure AD App registration
resource "null_resource" "log_redirect_uris" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Logging Redirect URIs:"
      echo "Redirect URI 1: ${local.static_web_app_url}/"
      echo "Redirect URI 2: ${local.static_web_app_url}/auth/callback"
      echo "Redirect URI 3: ${local.static_web_app_url}/auth/signin"
      echo "Redirect URI 4: ${local.static_web_app_url}/auth/signout"

    EOT
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [null_resource.read_static_web_app_info]
}


resource "azuread_application" "nextjs_app" {
  depends_on = [null_resource.deploy_static_web_app, null_resource.log_redirect_uris]

  display_name = "NextjsApp"
  web {
    redirect_uris = [
      "${local.static_web_app_url}/",
      "${local.static_web_app_url}/auth/callback",
      "${local.static_web_app_url}/auth/signin",
      "${local.static_web_app_url}/auth/signout"]
  }
  owners = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "nextjs_sp" {
  depends_on = [azuread_application.nextjs_app]
  client_id = azuread_application.nextjs_app.client_id
  app_role_assignment_required = false
  owners         = [data.azuread_client_config.current.object_id]
}

resource "time_rotating" "example" {
  rotation_days = 7
}

resource "azuread_application_password" "nextjs_app_secret" {
  application_id = azuread_application.nextjs_app.id 
  rotate_when_changed = {
    rotation = time_rotating.example.id
  }
}

output "application_id" {
  value = azuread_application.nextjs_app.id
}

output "application_secret" {
  value     = azuread_application_password.nextjs_app_secret.value
  sensitive = true
}

output "application_redirect_uris" {
  value = azuread_application.nextjs_app.web[0].redirect_uris
}

output "azuread_tenant_id" {
  value = data.azurerm_client_config.example.tenant_id
}