# This repo is suppose to create things with these 3 commands

terraform init

terraform plan -out myplan -var-file="secrets.tfvars"

terraform apply "myplan"


# Make a secrets.tfvars file and put this in

ghub_token = "ghub_token"


# Note change flask app ports to match the repo