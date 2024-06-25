
##############################################################################################################################
# Create resources for flask container app and make github actions in flask repo to push image to acr and deploy to container app
###########################
1) run the terraform init, plan and apply on main tf (in terraform directory)
2) go to flask app repo https://github.com/btindol/flask_template.git
3) make service principle az login then
    - az ad sp create-for-rbac --name "myServicePrincipal" --role Contributor --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}
4) take the json output and maek a github secret in new secret enviornment (environment: container-app-deploy) AZURE_CREDENTIALS
5) add the .github/workflows/deploy.yml` file which is below. (leave api managment stuff commented out.)
6) add api managment stuff init apply
7) make sure container app cors is enabled ( enable in terraform later)


########################################

```yaml
name: Deploy to Azure

on:
  push:
    branches:
      - main
      - terraform-flask-deployment

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    environment: container-app-deploy

    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up Azure CLI
      uses: azure/CLI@v1
      with:
        inlineScript: |
          echo "Azure CLI setup complete"

    - name: Login to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: Build and push Docker image
      run: |
        az acr build --registry acaalbumsbtindol --image album-api .

    - name: Create container app environment
      run: |
        az containerapp env create --name env-album-containerapps --resource-group album-containerapps --location canadacentral

    - name: Deploy image to container app
      run: |
        az containerapp create --name album-api --resource-group album-containerapps --environment env-album-containerapps --image "acaalbumsbtindol.azurecr.io/album-api" --target-port 8080 --ingress external --registry-server "acaalbumsbtindol.azurecr.io"

```

#################################
# To Do Next:
#######
1) attach api managment O AUTH addition as well as adding the rate limit factor
2) Make the next js app use api managment route *** done
3) make next js have auth 
4) might have to pay but enable front door which isnt allowd without subscription 
5) make the flask app structure actual model controller service and open api specs, bring in enviornment variables to do something like open api.
6) store terraform states in container app.
