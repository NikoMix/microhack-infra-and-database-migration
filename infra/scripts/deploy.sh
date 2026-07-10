#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-ttmh}"
LOCATION="${LOCATION:-swedencentral}"
SUFFIX="${SUFFIX:-$(az account show --query id -o tsv | tr -d '-' | cut -c1-6 | tr '[:upper:]' '[:lower:]')}"
ADMIN_OBJECT_ID="${ADMIN_OBJECT_ID:-}"
ADMIN_USERNAME="${ADMIN_USERNAME:-ttmhadmin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ADMIN_SOURCE_ADDRESS_PREFIX="${ADMIN_SOURCE_ADDRESS_PREFIX:-Internet}"
WORKLOAD_RAW_BASE_URL="${WORKLOAD_RAW_BASE_URL:-https://raw.githubusercontent.com/<owner>/<repo>/<branch>}"
AAD_ADMIN_OBJECT_ID="${AAD_ADMIN_OBJECT_ID:-}"
AAD_ADMIN_LOGIN="${AAD_ADMIN_LOGIN:-}"
POSTGRESQL_ADMIN_USERNAME="${POSTGRESQL_ADMIN_USERNAME:-ttmhpgadmin}"
POSTGRESQL_ADMIN_PASSWORD="${POSTGRESQL_ADMIN_PASSWORD:-}"
MYSQL_ADMIN_USERNAME="${MYSQL_ADMIN_USERNAME:-ttmhmysqladmin}"
MYSQL_ADMIN_PASSWORD="${MYSQL_ADMIN_PASSWORD:-}"
SKIP_SOURCE_ESTATE="${SKIP_SOURCE_ESTATE:-false}"
SKIP_TARGETS="${SKIP_TARGETS:-false}"
INCLUDE_SQLMI="${INCLUDE_SQLMI:-false}"
ENABLE_DEFENDER="${ENABLE_DEFENDER:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_DIR="$(cd "$SCRIPT_DIR/../bicep" && pwd)"
RG_SOURCE="rg-$PREFIX-source"
RG_PLATFORM="rg-$PREFIX-platform"
RG_DATA="rg-$PREFIX-data"
RG_AI="rg-$PREFIX-ai"

for rg in "$RG_SOURCE" "$RG_PLATFORM" "$RG_DATA" "$RG_AI"; do
  az group create --name "$rg" --location "$LOCATION" --tags env=microhack workload=tailwind-migration --only-show-errors >/dev/null
done

echo "What-if: platform"
az deployment sub what-if --location "$LOCATION" --template-file "$BICEP_DIR/main.bicep" --parameters prefix="$PREFIX" location="$LOCATION" suffix="$SUFFIX" adminObjectId="$ADMIN_OBJECT_ID" enableDefender="$ENABLE_DEFENDER"
az deployment sub create --location "$LOCATION" --template-file "$BICEP_DIR/main.bicep" --parameters prefix="$PREFIX" location="$LOCATION" suffix="$SUFFIX" adminObjectId="$ADMIN_OBJECT_ID" enableDefender="$ENABLE_DEFENDER"

if [[ "$SKIP_SOURCE_ESTATE" != "true" ]]; then
  [[ -n "$ADMIN_PASSWORD" ]] || { echo "ADMIN_PASSWORD is required unless SKIP_SOURCE_ESTATE=true." >&2; exit 1; }
  echo "What-if: source estate"
  az deployment group what-if --resource-group "$RG_SOURCE" --template-file "$BICEP_DIR/source-estate/main.bicep" --parameters prefix="$PREFIX" location="$LOCATION" adminUsername="$ADMIN_USERNAME" adminPassword="$ADMIN_PASSWORD" adminSourceAddressPrefix="$ADMIN_SOURCE_ADDRESS_PREFIX" workloadRawBaseUrl="$WORKLOAD_RAW_BASE_URL"
  az deployment group create --resource-group "$RG_SOURCE" --template-file "$BICEP_DIR/source-estate/main.bicep" --parameters prefix="$PREFIX" location="$LOCATION" adminUsername="$ADMIN_USERNAME" adminPassword="$ADMIN_PASSWORD" adminSourceAddressPrefix="$ADMIN_SOURCE_ADDRESS_PREFIX" workloadRawBaseUrl="$WORKLOAD_RAW_BASE_URL"
fi

if [[ "$SKIP_TARGETS" != "true" ]]; then
  [[ -n "$AAD_ADMIN_OBJECT_ID" && -n "$AAD_ADMIN_LOGIN" && -n "$POSTGRESQL_ADMIN_PASSWORD" && -n "$MYSQL_ADMIN_PASSWORD" ]] || { echo "AAD_ADMIN_OBJECT_ID, AAD_ADMIN_LOGIN, POSTGRESQL_ADMIN_PASSWORD, and MYSQL_ADMIN_PASSWORD are required unless SKIP_TARGETS=true." >&2; exit 1; }
  echo "What-if: data targets"
  az deployment group what-if --resource-group "$RG_DATA" --template-file "$BICEP_DIR/targets/main.bicep" --parameters prefix="$PREFIX" location="$LOCATION" suffix="$SUFFIX" platformResourceGroupName="$RG_PLATFORM" aadAdminObjectId="$AAD_ADMIN_OBJECT_ID" aadAdminLogin="$AAD_ADMIN_LOGIN" postgresqlAdminUsername="$POSTGRESQL_ADMIN_USERNAME" postgresqlAdminPassword="$POSTGRESQL_ADMIN_PASSWORD" mysqlAdminUsername="$MYSQL_ADMIN_USERNAME" mysqlAdminPassword="$MYSQL_ADMIN_PASSWORD"
  az deployment group create --resource-group "$RG_DATA" --template-file "$BICEP_DIR/targets/main.bicep" --parameters prefix="$PREFIX" location="$LOCATION" suffix="$SUFFIX" platformResourceGroupName="$RG_PLATFORM" aadAdminObjectId="$AAD_ADMIN_OBJECT_ID" aadAdminLogin="$AAD_ADMIN_LOGIN" postgresqlAdminUsername="$POSTGRESQL_ADMIN_USERNAME" postgresqlAdminPassword="$POSTGRESQL_ADMIN_PASSWORD" mysqlAdminUsername="$MYSQL_ADMIN_USERNAME" mysqlAdminPassword="$MYSQL_ADMIN_PASSWORD"
fi

if [[ "$INCLUDE_SQLMI" == "true" ]]; then
  [[ -n "$ADMIN_PASSWORD" ]] || { echo "ADMIN_PASSWORD is required for SQL MI." >&2; exit 1; }
  echo "WARN: SQL MI commonly takes 4-6 hours and can incur significant cost." >&2
  az deployment group what-if --resource-group "$RG_DATA" --template-file "$BICEP_DIR/targets/sqlmi.bicep" --parameters prefix="$PREFIX" location="$LOCATION" suffix="$SUFFIX" platformResourceGroupName="$RG_PLATFORM" administratorLogin="$ADMIN_USERNAME" administratorLoginPassword="$ADMIN_PASSWORD" aadAdminObjectId="$AAD_ADMIN_OBJECT_ID" aadAdminLogin="$AAD_ADMIN_LOGIN"
  az deployment group create --resource-group "$RG_DATA" --template-file "$BICEP_DIR/targets/sqlmi.bicep" --parameters prefix="$PREFIX" location="$LOCATION" suffix="$SUFFIX" platformResourceGroupName="$RG_PLATFORM" administratorLogin="$ADMIN_USERNAME" administratorLoginPassword="$ADMIN_PASSWORD" aadAdminObjectId="$AAD_ADMIN_OBJECT_ID" aadAdminLogin="$AAD_ADMIN_LOGIN"
fi
