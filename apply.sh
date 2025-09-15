#!/bin/bash
# ==================================================================================================
# Bootstrap Script for Mini Active Directory Deployment (Azure)
# Purpose:
#   - Validates the environment and dependencies before provisioning.
#   - Deploys Active Directory infrastructure in two phases:
#       1. Directory layer (Key Vault, AD base infra)
#       2. Server layer (Linux VM for Samba AD, domain join, secrets)
#   - Ensures failures are caught early with explicit exit conditions.
#
# Notes:
#   - Assumes `az` (Azure CLI) and `terraform` are installed and authenticated.
#   - Assumes `check_env.sh` validates required environment variables and tools.
#   - Automatically discovers the Key Vault name created in Phase 1 and passes
#     it into Phase 2 as a Terraform variable.
# ==================================================================================================

set -e  # Exit immediately on any unhandled command failure

# --------------------------------------------------------------------------------------------------
# Pre-flight Check: Validate environment
# Runs custom environment validation script (`check_env.sh`) to ensure:
#   - Azure CLI is logged in and subscription is set
#   - Terraform is installed
#   - Required variables (subscription ID, tenant ID, etc.) are present
# --------------------------------------------------------------------------------------------------
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# --------------------------------------------------------------------------------------------------
# Phase 1: Deploy Directory Layer
# - Provisions foundational resources such as Key Vault and base AD infrastructure.
# - Directory Terraform code is stored under ./01-directory.
# --------------------------------------------------------------------------------------------------
cd 01-directory

terraform init   # Initialize Terraform working directory (download providers/modules)
terraform apply -auto-approve   # Deploy Key Vault and other directory resources

# Error handling for Terraform apply
if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi
cd ..

# --------------------------------------------------------------------------------------------------
# Phase 2: Deploy Server Layer
# - Provisions Samba-based AD Domain Controller (Linux VM).
# - Discovers the Key Vault name from Azure (matching "ad-key-vault*") and passes
#   it into Terraform as a variable.
# --------------------------------------------------------------------------------------------------
cd 02-servers

# Query Azure for the Key Vault created in Phase 1 (first matching "ad-key-vault*")
vault=$(az keyvault list \
  --resource-group rstudio-project-rg \
  --query "[?starts_with(name, 'ad-key-vault')].name | [0]" \
  --output tsv)

echo "NOTE: Key vault for secrets is $vault"

terraform init   # Initialize Terraform in server layer
terraform apply -var="vault_name=$vault" -auto-approve   # Deploy VM, configure Samba AD

cd ..

#-------------------------------------------------------------------------------
# Phase 3: Build RStudio Image with Packer
# - Uses Packer to create a custom VM image with RStudio and R pre-installed.
#-------------------------------------------------------------------------------

cd 03-packer                        # Enter Linux Packer template directory
packer init .                       # Initialize Packer plugins
# packer build \
#   -var="client_id=$ARM_CLIENT_ID" \
#   -var="client_secret=$ARM_CLIENT_SECRET" \
#   -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
#   -var="tenant_id=$ARM_TENANT_ID" \
#   -var="resource_group=rstudio-project-rg" \
#   rstudio_image.pkr.hcl             # Packer HCL template for RStudio image

cd ..   

#-------------------------------------------------------------------------------
# Phase 4: Build RStudio Cluster with a Virtual Machine Scale Set
#-------------------------------------------------------------------------------

rstudio_image_name=$(az image list \
  --resource-group rstudio-project-rg \
  --query "[?starts_with(name, 'rstudio_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)                     # Grab the latest rstudio_image by name sort

echo "NOTE: Using the latest image ($rstudio_image_name) in rstudio-project-rg."

# Fail if image was not found
if [ -z "$rstudio_image_name" ]; then
  echo "ERROR: No image with the prefix 'rstudio_image' was found in the resource group 'rstudio-project-rg'. Exiting."
  exit 1
fi

secretsJson=$(az keyvault secret show \
  --name ubuntu-credentials \
  --vault-name ${vault} \
  --query value \
  -o tsv)                           # Retrieve JSON secret with credentials

password=$(echo "$secretsJson" | jq -r '.password')  # Extract `password` field from the secret JSON

storage_account=$(az storage account list \
  --resource-group rstudio-project-rg \
  --query "[?starts_with(name, 'nfs')].name | [0]" \
  -o tsv 2>/dev/null)

cd 04-cluster                        # Enter Linux Packer template directory
terraform init  
terraform apply -var="vault_name=$vault" -auto-approve   # Deploy VM, configure Samba AD
cd ..

