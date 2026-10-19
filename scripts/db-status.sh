#!/usr/bin/env bash
# scripts/db-status.sh
# Shows the status of the shared PostgreSQL instance and the databases it hosts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "$SCRIPT_DIR/lib/db.sh"

db_status

if db_is_running; then
  echo
  echo "Data directory: $POSTGRES_DATA_DIR"
  echo
  echo "Databases:"
  db_list | sed 's/^/  - /'
else
  echo
  echo "Data directory: $POSTGRES_DATA_DIR"
  echo "The database service is not running. Start it with scripts/db-up.sh."
fi
