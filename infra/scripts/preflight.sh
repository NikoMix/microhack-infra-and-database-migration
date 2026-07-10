#!/usr/bin/env bash
set -euo pipefail

LOCATION="${LOCATION:-swedencentral}"
REGISTER="${REGISTER:-false}"

command -v az >/dev/null 2>&1 || { echo "Azure CLI (az) is required." >&2; exit 1; }
az account show --output none >/dev/null 2>&1 || { echo "Run az login before deploying." >&2; exit 1; }

echo "Azure account: $(az account show --query user.name -o tsv)"
echo "Subscription: $(az account show --query '[name,id]' -o tsv)"

providers=(
  Microsoft.Sql
  Microsoft.DBforPostgreSQL
  Microsoft.DBforMySQL
  Microsoft.DataFactory
  Microsoft.Compute
  Microsoft.Network
  Microsoft.KeyVault
  Microsoft.OperationalInsights
  Microsoft.Security
  Microsoft.DevTestLab
)

for provider in "${providers[@]}"; do
  state="$(az provider show --namespace "$provider" --query registrationState -o tsv)"
  if [[ "$state" != "Registered" ]]; then
    if [[ "$REGISTER" == "true" ]]; then
      echo "Registering $provider..."
      az provider register --namespace "$provider" --only-show-errors >/dev/null
    else
      echo "WARN: $provider is $state. Run REGISTER=true ./preflight.sh or az provider register --namespace $provider" >&2
    fi
  else
    echo "$provider registered"
  fi
done

if [[ "$(az account list-locations --query "[?name=='$LOCATION'] | length(@)" -o tsv)" == "0" ]]; then
  echo "Region '$LOCATION' is not available to this subscription." >&2
  exit 1
fi

echo "Region available: $LOCATION"
echo "Preflight complete. Check quotas/SKU availability before class delivery."
