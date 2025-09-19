#!/bin/bash

# ------------------------------------------------------------------------------
# Phase 3: Destroy Directory Layer
# - Removes foundational resources such as Mini-AD, Key Vault,
#   and resource group–level roles
# - Executed last to ensure no dependencies remain
# ------------------------------------------------------------------------------
cd 01-directory

terraform init
terraform destroy -auto-approve

cd ..
