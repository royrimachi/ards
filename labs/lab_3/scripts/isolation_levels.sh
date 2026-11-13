#!/usr/bin/env bash
# labs/lab_3/scripts/isolation_levels.sh
# Instructions for comparing PostgreSQL transaction isolation levels.

set -euo pipefail

# Sources use SCRIPT_DIR so the script works from any working directory.
# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

db_require_running

echo "========================================"
echo " Isolation levels"
echo "========================================"
echo "Open two terminals. In each, run:"
echo "  $PROJECT_ROOT/scripts/db-shell.sh $LAB_DB_NAME"
echo
echo "Session A (READ COMMITTED):"
echo "  BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;"
echo "  SELECT * FROM account;"
echo
echo "Session B (REPEATABLE READ):"
echo "  BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;"
echo "  SELECT * FROM account;"
echo
echo "READ COMMITTED sees the latest committed data at each statement,"
echo "while REPEATABLE READ keeps the snapshot from transaction start."
echo
echo "To record a lock wait at a specific isolation level, run:"
echo "  $SCRIPT_DIR/log_concurrency.sh --scenario lock-wait --isolation \"REPEATABLE READ\""
