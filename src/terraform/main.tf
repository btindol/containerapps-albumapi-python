
###################################################################################################
# Run 1: just the stuff in this seciton

# SECTION 1: CREATE THESE RESOURCES (RESOURCE GROUP, CONTAINER REGISTRY, CONTAINER APP ENVIRONMENT)
provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  default = "album-containerapps"
}


variable "acr_name" {
  default = "acaalbumsbtindol"
}
variable "location" {
  default = "canadacentral"
}

variable "environment_name" {
  default = "env-album-containerapps"
}

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
  resource_group_name = var.resource_group_name
  location            = var.location
}
###################################################################################################
# STEP 2:  Run flask app creation and create static web app
################################################################

###################################################################################################
# SECTION 3: CREATE THESE RESOURCES (API MANAGEMENT, API, API OPERATION, API OPERATION POLICY, API PRODUCT, PRODUCT API LINK, AZURE AD APP REGISTRATION, AZURE AD APP PASSWORD)

# Change the values: flask_app_url, frontend_url, azuread_tenant_id, 


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

variable "flask_app_url" {
  default = "https://album-api.salmonground-7f30861a.canadacentral.azurecontainerapps.io"
}
variable "frontend_url" {
  default = "https://happy-ground-0658ef70f.5.azurestaticapps.net"  # Frontend URL
}


resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "My Company"
  publisher_email     = "company@terraform.io"
  sku_name            = "Developer_1"  # Use Developer SKU for non-production environments
}

# API Management Backend
resource "azurerm_api_management_backend" "example_backend" {
  name                = "example-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = var.flask_app_url
}

# API Management API
resource "azurerm_api_management_api" "apim_api" {
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
# API Management API Operation Policy
resource "azurerm_api_management_api_operation_policy" "apim_api_operation_policy" {
  operation_id        = azurerm_api_management_api_operation.apim_api_operation.operation_id
  api_name            = azurerm_api_management_api.apim_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  xml_content         =  <<XML
<policies>
    <inbound>
        <set-header name="Access-Control-Allow-Origin" exists-action="override">
            <value>${var.frontend_url}</value>
        </set-header>
        <set-header name="Access-Control-Allow-Methods" exists-action="override">
            <value>GET, OPTIONS</value>
        </set-header>
        <set-header name="Access-Control-Allow-Headers" exists-action="override">
            <value>Content-Type, Authorization, Ocp-Apim-Subscription-Key</value>
        </set-header>
        <set-backend-service base-url="${var.flask_app_url}" />
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
variable "azuread_tenant_id" {
  description = "Azure AD tenant ID"
  default     = "9484a8f8-13d0-471a-9f99-9f4aa9c2159f"  # Replace with your actual Azure AD tenant ID
}


resource "random_password" "nextjs_app_password" {
  length  = 16
  special = true
}

data "azuread_client_config" "current" {}

resource "azuread_application" "nextjs_app" {
  display_name = "NextjsApp"
  web {
    redirect_uris = [
      "${var.frontend_url}/",
      "${var.frontend_url}/auth/callback",
      "${var.frontend_url}/auth/signin",
      "${var.frontend_url}/auth/signout",
      "http://localhost:3000/",
      "http://localhost:3000/auth/callback",
      "http://localhost:3000/auth/signin",
      "http://localhost:3000/auth/signout",
      "http://localhost:3000/api/auth/callback/azure-ad"
    ]
  }
  owners = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "nextjs_sp" {
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
