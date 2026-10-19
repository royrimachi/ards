#!/usr/bin/env bash
# start_container.sh
# Starts the shared PostgreSQL instance and provisions lab_2's database.
# Safe to run repeatedly; existing data is preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

echo "Starting the shared PostgreSQL container..."
db_up
db_wait_ready
db_create "$LAB_DB_NAME"

echo
echo "Container ready. Database '$LAB_DB_NAME' is available."
db_status
