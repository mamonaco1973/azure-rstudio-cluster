#!/bin/bash
# ==================================================================================================
# Apply Script for RStudio Cluster Deployment on Azure
#
# Purpose:
#   - Validates the environment and dependencies before provisioning.
#   - Deploys a complete RStudio cluster environment in **four phases**:
#       1. Directory + Identity Layer:
#          - Deploys Mini Active Directory (Samba 4), networking (VNet, subnets, NSGs),
#            and Key Vault for credential storage.
#       2. Services Layer:
#          - Provisions shared storage (Azure Files NFS), the NFS-Gateway VM (Linux),
#            and an AD Admin Windows Server for domain management.
#       3. Image Layer:
#          - Uses Packer to build a custom RStudio VM image with R + RStudio pre-installed.
#       4. Cluster Layer:
#          - Deploys an RStudio cluster via VM Scale Set (VMSS), joined to AD and backed by NFS.
#
# Notes:
#   - Assumes `az` (Azure CLI), `terraform`, and `packer` are installed and authenticated.
#   - Assumes `check_env.sh` validates required environment variables and tools.
#   - Secrets and credentials are stored in Azure Key Vault (Phase 1) and retrieved securely.
#   - The latest RStudio image from Phase 3 is automatically discovered and used in Phase 4.
# ==================================================================================================

set -e  # Exit immediately on any unhandled command failure

# --------------------------------------------------------------------------------------------------
# Pre-flight Check: Validate environment
# Runs custom environment validation script (`check_env.sh`) to ensure:
#   - Azure CLI is logged in and subscription is set
#   - Terraform is installed
#   - Packer is installed
#   - Required variables (subscription ID, tenant ID, etc.) are present
# --------------------------------------------------------------------------------------------------
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# --------------------------------------------------------------------------------------------------
# Phase 1: Deploy Directory + Identity Layer
# - Deploys foundational resources:
#     * Virtual network, subnets, and security groups
#     * Key Vault for secrets storage
#     * Samba-based Mini Active Directory Domain Controller (Linux VM)
# --------------------------------------------------------------------------------------------------
cd 01-directory

terraform init                        # Initialize Terraform working directory
terraform apply -auto-approve         # Deploy VNet, Key Vault, Mini-AD, and supporting resources

# Exit if deployment fails
if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi
cd ..

# --------------------------------------------------------------------------------------------------
# Phase 2: Deploy Services Layer
# - Provisions supporting services:
#     * Azure Files (NFS storage account)
#     * NFS-Gateway VM (Linux, domain joined to Mini-AD)
#     * AD Admin Windows Server (management and GUI tools)
# - Discovers the Key Vault name from Phase 1 for secret retrieval.
# --------------------------------------------------------------------------------------------------
cd 02-servers

# Query Azure for the Key Vault created in Phase 1 (first matching "ad-key-vault*")
vault=$(az keyvault list \
  --resource-group rstudio-project-rg \
  --query "[?starts_with(name, 'ad-key-vault')].name | [0]" \
  --output tsv)

echo "NOTE: Key Vault for secrets is $vault"

terraform init
terraform apply -var="vault_name=$vault" -auto-approve   # Deploy NFS, gateway, and Windows Admin server
cd ..

# --------------------------------------------------------------------------------------------------
# Phase 3: Build RStudio Image with Packer
# - Uses Packer to build a custom Linux VM image with R + RStudio pre-installed.
# - Authentication is handled with Azure service principal credentials.
# --------------------------------------------------------------------------------------------------
cd 03-packer

packer init .
packer build \
  -var="client_id=$ARM_CLIENT_ID" \
  -var="client_secret=$ARM_CLIENT_SECRET" \
  -var="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -var="tenant_id=$ARM_TENANT_ID" \
  -var="resource_group=rstudio-project-rg" \
  rstudio_image.pkr.hcl

cd ..

# --------------------------------------------------------------------------------------------------
# Phase 4: Deploy RStudio Cluster with a Virtual Machine Scale Set
# - Discovers the latest RStudio image from Phase 3.
# - Retrieves Ubuntu credentials from Key Vault.
# - Discovers NFS storage account provisioned in Phase 2.
# - Deploys RStudio VMSS cluster joined to Mini-AD and backed by NFS storage.
# --------------------------------------------------------------------------------------------------

# Discover the latest RStudio image in the resource group (prefix: rstudio_image)
rstudio_image_name=$(az image list \
  --resource-group rstudio-project-rg \
  --query "[?starts_with(name, 'rstudio_image')]|sort_by(@, &name)[-1].name" \
  --output tsv)

echo "NOTE: Using the latest image ($rstudio_image_name) in rstudio-project-rg."

# Fail and exit if no image was found
if [ -z "$rstudio_image_name" ]; then
  echo "ERROR: No image with the prefix 'rstudio_image' was found in rstudio-project-rg. Exiting."
  exit 1
fi

# Retrieve Ubuntu credentials from Key Vault
secretsJson=$(az keyvault secret show \
  --name ubuntu-credentials \
  --vault-name ${vault} \
  --query value \
  -o tsv)

password=$(echo "$secretsJson" | jq -r '.password')  # Extract password from secret JSON

# Discover the NFS storage account name from Phase 2
storage_account=$(az storage account list \
  --resource-group rstudio-project-rg \
  --query "[?starts_with(name, 'nfs')].name | [0]" \
  -o tsv 2>/dev/null)

# Deploy the RStudio Cluster (VMSS) with Terraform
cd 04-cluster
terraform init
terraform apply -var="vault_name=$vault" \
                -var="nfs_storage_account=$storage_account" \
                -var="ubuntu_password=$password" \
                -var="rstudio_image_name=$rstudio_image_name" \
                -auto-approve

cd ..
echo "NOTE: Azure RStudio Cluster deployment completed successfully."
