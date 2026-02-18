#!/bin/bash
# =========================================================================================
# validate.sh - RStudio VMSS Quick Start Validation (Azure)
# -----------------------------------------------------------------------------------------
# Purpose:
#   - Poll Azure Application Gateway backend health until a healthy RStudio
#     server is found.
#   - Output Quick Start endpoints in consistent formatted layout.
#
# Scope:
#   - Waits for healthy backend servers.
#   - Discovers:
#       - Windows admin host (RDP)
#       - Linux NFS gateway host
#       - Key Vault (if present)
#       - RStudio App Gateway public URL
#
# Requirements:
#   - Azure CLI installed and authenticated (az login)
# =========================================================================================

set -euo pipefail

# -----------------------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------------------
RESOURCE_GROUP="rstudio-vmss-rg"
SERVERS_RESOURCE_GROUP="rstudio-servers-rg"

APP_GATEWAY_NAME="rstudio-app-gateway"
APP_GATEWAY_PIP_NAME="rstudio-app-gateway-pip"

WIN_LABEL_PREFIX="win-ad-"
LINUX_LABEL_PREFIX="nfs-gateway-"
KEYVAULT_PREFIX="ad-key-vault"

CHECK_INTERVAL=30
MAX_RETRIES=20

# -----------------------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------------------
az_trim() {
  xargs 2>/dev/null || true
}

get_public_fqdn_by_domain_label_prefix() {
  local rg="$1"
  local prefix="$2"

  az network public-ip list \
    --resource-group "${rg}" \
    --query "[?dnsSettings && starts_with(dnsSettings.domainNameLabel, '${prefix}')].dnsSettings.fqdn | [0]" \
    --output tsv | az_trim
}

get_key_vault_by_prefix() {
  local rg="$1"
  local prefix="$2"

  az keyvault list \
    --resource-group "${rg}" \
    --query "[?starts_with(name, '${prefix}')].name | [0]" \
    --output tsv | az_trim
}

check_backend_health() {
  az network application-gateway show-backend-health \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${APP_GATEWAY_NAME}" \
    --query "backendAddressPools[].backendHttpSettingsCollection[].servers[?health == 'Healthy']" \
    --output tsv
}

# -----------------------------------------------------------------------------------------
# Wait for Healthy Backend
# -----------------------------------------------------------------------------------------
echo "NOTE: Waiting for at least one healthy backend RStudio server..."

for ((i = 1; i <= MAX_RETRIES; i++)); do
  HEALTHY_SERVERS=$(check_backend_health)

  if [[ -n "${HEALTHY_SERVERS}" ]]; then
    echo "NOTE: At least one healthy backend RStudio server found!"
    break
  fi

  echo "NOTE: Retry ${i}/${MAX_RETRIES}: No healthy servers yet. Retrying..."
  sleep "${CHECK_INTERVAL}"

  if [[ "$i" -eq "$MAX_RETRIES" ]]; then
    echo "ERROR: Timeout reached. No healthy backend servers found."
    exit 1
  fi
done

# -----------------------------------------------------------------------------------------
# Lookups
# -----------------------------------------------------------------------------------------
windows_fqdn="$(get_public_fqdn_by_domain_label_prefix "${SERVERS_RESOURCE_GROUP}" "${WIN_LABEL_PREFIX}")"
linux_fqdn="$(get_public_fqdn_by_domain_label_prefix "${SERVERS_RESOURCE_GROUP}" "${LINUX_LABEL_PREFIX}")"
vault_name="$(get_key_vault_by_prefix "${RESOURCE_GROUP}" "${KEYVAULT_PREFIX}")"

rstudio_dns="$(az network public-ip show \
  --name "${APP_GATEWAY_PIP_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query "dnsSettings.fqdn" \
  --output tsv | az_trim)"

# -----------------------------------------------------------------------------------------
# Quick Start Output
# -----------------------------------------------------------------------------------------
echo ""
echo "============================================================================"
echo "RStudio VMSS Quick Start - Validation Output (Azure)"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: Resource Group:"     "${RESOURCE_GROUP}"
printf "%-28s %s\n" "NOTE: Key Vault:"          "${vault_name}"

echo ""

printf "%-28s %s\n" "NOTE: Windows RDP Host:"   "${windows_fqdn}"
printf "%-28s %s\n" "NOTE: NFS Gateway Host:"   "${linux_fqdn}"

echo ""

printf "%-28s %s\n" "NOTE: RStudio URL:"        "http://${rstudio_dns}"

echo ""
