# This repo is suppose to create things with these 3 commands

terraform init

terraform plan -out myplan -var-file="secrets.tfvars"

terraform apply "myplan"


# Make a secrets.tfvars file and put this in

ghub_token = "ghub_token"


# Note change flask app ports to match the repo
- Need to go into main.tf in src/terraform/main.tf and change url for nextjs and flask if want.
- Need to go to the nextjs page.tsx file in that repo and change to the created flask api route.
- Need to go change the enviornment varialbes in each repo to make it work.
- Need to add enviornment secrets for the static web app so it will work
- Add the tenant id to staticwebapp.json file for auth in nextjs if change.


# TO DO:
- Add api managment
- Add security groups 
- Add aad and auth
- Add front door
- Change the DNS name 
- Test things
- Change container app port from 80 to match the flask repo!!!!!



# Services created

terraform import azurerm_resource_group.main /subscriptions/d88f3feb-9574-4c38-8c47-4f188da558d6/resourceGroups/album-containerappsz


terraform import -var-file="secrets.tfvars" azurerm_resource_group.main /subscriptions/d88f3feb-9574-4c38-8c47-4f188da558d6/resourceGroups/album-containerappsz


terraform import -var-file="secrets.tfvars" azurerm_container_app_environment.main /subscriptions/d88f3feb-9574-4c38-8c47-4f188da558d6/resourceGroups/album-containerappsz/providers/Microsoft.App/managedEnvironments/env-album-containerappsz

terraform import -var-file="secrets.tfvars" azurerm_user_assigned_identity.container_app_identity /subscriptions/d88f3feb-9574-4c38-8c47-4f188da558d6/resourceGroups/album-containerappsz/providers/Microsoft.ManagedIdentity/userAssignedIdentities/container-app-identityz


terraform import -var-file="secrets.tfvars" azurerm_container_registry.main /subscriptions/d88f3feb-9574-4c38-8c47-4f188da558d6/resourceGroups/album-containerappsz/providers/Microsoft.ContainerRegistry/registries/acaalbumsbtindolzz

terraform import -var-file="secrets.tfvars" azurerm_role_assignment.acr_pull_role /subscriptions/d88f3feb-9574-4c38-8c47-4f188da558d6/resourceGroups/album-containerappsz/providers/Microsoft.ContainerRegistry/registries/acaalbumsbtindolzz/providers/Microsoft.Authorization/roleAssignments/ff6b0974-9ee7-4249-e30a-2776a67beb64


terraform import -var-file="secrets.tfvars" azurerm_container_app.main /subscriptions/d88f3feb-9574-4c38-8c47-4f188da558d6/resourceGroups/album-containerappsz/providers/Microsoft.App/containerApps/flask-app
