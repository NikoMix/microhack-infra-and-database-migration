#!/usr/bin/env bash
set -euo pipefail

DB_NAME="${TAILWIND_MYSQL_DATABASE:-TailwindSessions}"
MYSQL_HOST="${TAILWIND_MYSQL_HOST:-localhost}"
MYSQL_USER="${TAILWIND_MYSQL_USER:-root}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v mysql >/dev/null 2>&1; then
  echo "mysql client was not found. Install MySQL client tools before running this script." >&2
  exit 1
fi

mysql_admin() {
  mysql --host="${MYSQL_HOST}" --user="${MYSQL_USER}" --batch --raw "$@"
}

mysql_admin -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql_admin "${DB_NAME}" < "${SCRIPT_DIR}/schema.sql"
mysql_admin "${DB_NAME}" < "${SCRIPT_DIR}/seed.sql"

echo "Tailwind MySQL workload installation completed."
