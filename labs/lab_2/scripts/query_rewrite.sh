#!/usr/bin/env bash
# query_rewrite.sh
# Demonstrates rewriting a subquery into a JOIN for optimization.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

db_require_running

echo "Subquery form EXPLAIN ANALYZE:"
db_psql "$LAB_DB_NAME" -c "
  EXPLAIN ANALYZE
  SELECT e.*
  FROM employees e
  WHERE e.department_id IN (SELECT id FROM departments WHERE location = 'New York');"

echo
echo "Rewritten JOIN form EXPLAIN ANALYZE:"
db_psql "$LAB_DB_NAME" -c "
  EXPLAIN ANALYZE
  SELECT e.*
  FROM employees e
  JOIN departments d ON e.department_id = d.id
  WHERE d.location = 'New York';"
