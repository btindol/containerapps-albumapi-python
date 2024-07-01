# GO TO THIS BRANCH
terraform-flask-static-web-deployment-v1

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


