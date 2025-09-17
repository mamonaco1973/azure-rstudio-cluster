#!/bin/bash

# Variables
RESOURCE_GROUP="rstudio-vmss-rg"
APP_GATEWAY_NAME="rstudio-app-gateway"  
CHECK_INTERVAL=30  
MAX_RETRIES=20     

# Function to check backend health
check_backend_health() {
    az network application-gateway show-backend-health \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_GATEWAY_NAME" \
        --query "backendAddressPools[].backendHttpSettingsCollection[].servers[?health == 'Healthy']" \
        -o tsv
}

# Wait for healthy backend servers
echo "NOTE: Waiting for at least one healthy backend server..."
for ((i = 1; i <= MAX_RETRIES; i++)); do
    HEALTHY_SERVERS=$(check_backend_health)

    if [[ -n "$HEALTHY_SERVERS" ]]; then
        echo "NOTE: At least one healthy backend server found!"
	
	export DNS_NAME=$(az network public-ip show \
 	    --name rstudio-app-gateway-pip \
            --resource-group $RESOURCE_GROUP \
            --query "dnsSettings.fqdn" \
            --output tsv)

	echo "NOTE: RStudio Application URL - http://$DNS_NAME"
        exit 0
    fi

    echo "NOTE: Retry $i/$MAX_RETRIES: No healthy backend servers yet. Retrying in $CHECK_INTERVAL seconds..."
    sleep "$CHECK_INTERVAL"
done

echo "ERROR: Timeout reached. No healthy backend servers found."
exit 1