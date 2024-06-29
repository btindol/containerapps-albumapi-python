variable "resource_group_name" {
  default = "album-containerappszz"
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
        value = "80" # Ensure this matches the Dockerfile port
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
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

      # Generate and retrieve the Static Web App API token
      $SWA_API_TOKEN = az staticwebapp secrets list `
        --name $env:STATIC_WEB_APP_NAME `
        --resource-group $env:RESOURCE_GROUP_NAME `
        --query "properties.apiKey" `
        --output tsv


    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

output "container_app_fqdn" {
  value = azurerm_container_app.main.latest_revision_fqdn
}
