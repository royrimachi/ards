#!/usr/bin/env bash
# create_indexes.sh
# Creates advanced indexes on the employees table, then checks the effect with
# EXPLAIN. Idempotent: existing indexes are left in place.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

db_require_running

echo "Creating advanced indexes..."
db_psql "$LAB_DB_NAME" \
  -c "CREATE INDEX IF NOT EXISTS idx_dept_lastname ON employees(department, last_name);"

db_psql "$LAB_DB_NAME" \
  -c "CREATE INDEX IF NOT EXISTS idx_email_lower ON employees((lower(email)));"

echo
echo "Indexes created. Checking query plan with EXPLAIN..."
db_psql "$LAB_DB_NAME" \
  -c "EXPLAIN SELECT * FROM employees WHERE department = 'Sales' AND last_name = 'Smith';"
