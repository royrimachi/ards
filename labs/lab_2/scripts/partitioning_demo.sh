#!/usr/bin/env bash
# partitioning_demo.sh
# Demonstrates list partitioning by department (optional advanced exercise).
# Idempotent: the partitioned table and the Sales partition are created once.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

db_require_running

echo "Demonstrating partitioning (advanced)..."

db_psql "$LAB_DB_NAME" -c "
  CREATE TABLE IF NOT EXISTS employees_partitioned (
    id            SERIAL,
    first_name    TEXT,
    last_name     TEXT,
    department    TEXT,
    department_id INT,
    email         TEXT,
    -- A partitioned table's primary key must include the partition key.
    PRIMARY KEY (id, department)
  ) PARTITION BY LIST (department);

  CREATE TABLE IF NOT EXISTS employees_sales
    PARTITION OF employees_partitioned
    FOR VALUES IN ('Sales');"

echo
echo "Partitioned table ready. 'Sales' employees can be routed to employees_sales."
