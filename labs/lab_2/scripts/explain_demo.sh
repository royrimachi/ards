#!/usr/bin/env bash
# explain_demo.sh
# Demonstrates basic EXPLAIN and EXPLAIN ANALYZE in lab_2's database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

db_require_running

echo "Demonstrating basic EXPLAIN..."
db_psql "$LAB_DB_NAME" \
  -c "EXPLAIN SELECT * FROM employees WHERE department = 'Sales';"

echo
echo "Demonstrating EXPLAIN ANALYZE..."
db_psql "$LAB_DB_NAME" \
  -c "EXPLAIN ANALYZE SELECT * FROM employees WHERE last_name = 'Smith';"
