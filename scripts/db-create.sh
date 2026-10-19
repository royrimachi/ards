#!/usr/bin/env bash
# scripts/db-create.sh <database>
# Creates a database in the shared PostgreSQL instance (idempotent).
#
# Future labs can use this for their own database, or add the name to
# POSTGRES_DATABASES in .env so db-up.sh creates it automatically.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "$SCRIPT_DIR/lib/db.sh"

if (( $# != 1 )); then
  echo "usage: $0 <database>" >&2
  exit 1
fi

db_require_running
db_create "$1"

echo
echo "Databases:"
db_list | sed 's/^/  - /'
