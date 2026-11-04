#!/usr/bin/env bash
# labs/lab_3/scripts/simulate_deadlock.sh
# Instructions for creating a deadlock with two concurrent transactions.

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
echo " Deadlock simulation"
echo "========================================"
echo "Open two terminals. In each, run:"
echo "  $PROJECT_ROOT/scripts/db-shell.sh $LAB_DB_NAME"
echo
echo "Session A:"
echo "  BEGIN;"
echo "  UPDATE account SET balance = balance + 10 WHERE owner_name = 'Alice';"
echo "  UPDATE account SET balance = balance + 5 WHERE owner_name = 'Bob';"
echo
echo "Session B (start after Session A's first UPDATE):"
echo "  BEGIN;"
echo "  UPDATE account SET balance = balance + 20 WHERE owner_name = 'Bob';"
echo "  UPDATE account SET balance = balance + 5 WHERE owner_name = 'Alice';"
echo
echo "The second UPDATE in each session waits for the row locked by the other."
echo "PostgreSQL detects the deadlock and rolls back one transaction."
