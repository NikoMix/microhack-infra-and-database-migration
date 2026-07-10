#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-ttmh}"
FORCE="${FORCE:-false}"
resource_groups=("rg-$PREFIX-source" "rg-$PREFIX-platform" "rg-$PREFIX-data" "rg-$PREFIX-ai")

if [[ "$FORCE" != "true" ]]; then
  echo "Delete resource groups: ${resource_groups[*]}?"
  read -r -p "Type DELETE to continue: " answer
  if [[ "$answer" != "DELETE" ]]; then
    echo "Teardown cancelled."
    exit 0
  fi
fi

for rg in "${resource_groups[@]}"; do
  if [[ "$(az group exists --name "$rg" -o tsv)" == "true" ]]; then
    echo "Deleting $rg..."
    az group delete --name "$rg" --yes --no-wait
  fi
done
