#!/usr/bin/env bash
# scripts/db-info.sh
# Prints connection details and JDBC URLs for the shared PostgreSQL instance.
# Useful for DataGrip or any SQL client. The password is never printed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "$SCRIPT_DIR/lib/db.sh"

db_require_running

host="127.0.0.1"

echo "Shared PostgreSQL connection"
echo "  Host:     $host"
echo "  Port:     $POSTGRES_PORT"
echo "  User:     $POSTGRES_USER"
echo "  Password: see POSTGRES_PASSWORD in $ENV_FILE"
echo
echo "Databases and JDBC URLs:"

while IFS= read -r db_name; do
  [[ -z "$db_name" ]] && continue
  printf '  - %s\n' "$db_name"
  printf '      jdbc:postgresql://%s:%s/%s\n' "$host" "$POSTGRES_PORT" "$db_name"
done < <(db_list)
