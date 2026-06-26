#!/usr/bin/env bash
set -euo pipefail

DB_NAME="${TAILWIND_PG_DATABASE:-TailwindCatalog}"
ROLE_NAME="${TAILWIND_PG_ROLE:-tailwind_catalog_owner}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql was not found. Install PostgreSQL client tools before running this script." >&2
  exit 1
fi

admin_psql() {
  if [[ -n "${POSTGRES_ADMIN_URL:-}" ]]; then
    psql "${POSTGRES_ADMIN_URL}" -v ON_ERROR_STOP=1 "$@"
  elif psql -d postgres -v ON_ERROR_STOP=1 -c "SELECT 1;" >/dev/null 2>&1; then
    psql -d postgres -v ON_ERROR_STOP=1 "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 "$@"
  else
    echo "No PostgreSQL admin connection available. Set POSTGRES_ADMIN_URL." >&2
    exit 1
  fi
}

admin_psql <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${ROLE_NAME}') THEN
    CREATE ROLE ${ROLE_NAME} LOGIN;
  END IF;
END
\$\$;
SQL

if ! admin_psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  admin_psql -c "CREATE DATABASE \"${DB_NAME}\" OWNER ${ROLE_NAME};"
fi

admin_psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
admin_psql -d "${DB_NAME}" -f "${SCRIPT_DIR}/schema.sql"
admin_psql -d "${DB_NAME}" -f "${SCRIPT_DIR}/seed.sql"

echo "Tailwind PostgreSQL workload installation completed."
