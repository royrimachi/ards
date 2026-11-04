#!/usr/bin/env bash
# labs/lab_3/scripts/create_db_env.sh
# Starts the shared PostgreSQL service and initializes the concurrency lab.

set -euo pipefail

# Sources use SCRIPT_DIR so the script works from any working directory.
# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

echo "========================================"
echo " Transactions & Concurrency Lab setup"
echo "========================================"

db_up
db_wait_ready
db_create "$LAB_DB_NAME"
db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/init_db.sql"

echo
echo "Database setup completed."
echo "Database: $LAB_DB_NAME"
echo "Connect with: $PROJECT_ROOT/scripts/db-shell.sh $LAB_DB_NAME"
