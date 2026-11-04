#!/usr/bin/env bash
# labs/lab_3/scripts/mvcc_demo.sh
# Instructions for demonstrating PostgreSQL MVCC snapshots.

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
echo " MVCC demonstration"
echo "========================================"
echo "Open two terminals. In each, run:"
echo "  $PROJECT_ROOT/scripts/db-shell.sh $LAB_DB_NAME"
echo
echo "Session A:"
echo "  BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;"
echo "  SELECT * FROM account;"
echo
echo "Session B:"
echo "  BEGIN;"
echo "  UPDATE account SET balance = balance + 100 WHERE owner_name = 'Alice';"
echo "  COMMIT;"
echo
echo "Session A (still in its original transaction):"
echo "  SELECT * FROM account;"
echo "  -- The updated Alice balance is not visible in this snapshot."
echo "  COMMIT;"
echo "  BEGIN;"
echo "  SELECT * FROM account;"
echo "  -- The committed update is visible in the new transaction."
