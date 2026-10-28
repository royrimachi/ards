#!/usr/bin/env bash
# partitioning_demo.sh
# Demonstrates declarative list partitioning by department (advanced exercise).
#
# Rows are always inserted into the parent table, never into a partition by
# name: PostgreSQL routes each row to the partition whose bounds match the
# department value. Every department used by insert_data.sql gets its own
# partition, because a value without a matching partition makes the INSERT fail.
#
# Idempotent: the parent, the partitions and the sample rows are created once.
#
# Usage: partitioning_demo.sh [--bulk]
#   --bulk  also copy the existing employees rows through the parent table

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

BULK=0
for arg in "$@"; do
  case "$arg" in
    --bulk) BULK=1 ;;
    -h|--help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown argument '$arg' (expected --bulk)" >&2
      exit 2
      ;;
  esac
done

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

  -- One partition per department value used by insert_data.sql. The partition
  -- bounds are what make routing unambiguous.
  CREATE TABLE IF NOT EXISTS employees_sales
    PARTITION OF employees_partitioned FOR VALUES IN ('Sales');
  CREATE TABLE IF NOT EXISTS employees_engineering
    PARTITION OF employees_partitioned FOR VALUES IN ('Engineering');
  CREATE TABLE IF NOT EXISTS employees_marketing
    PARTITION OF employees_partitioned FOR VALUES IN ('Marketing');
  CREATE TABLE IF NOT EXISTS employees_finance
    PARTITION OF employees_partitioned FOR VALUES IN ('Finance');
  CREATE TABLE IF NOT EXISTS employees_hr
    PARTITION OF employees_partitioned FOR VALUES IN ('HR');
  CREATE TABLE IF NOT EXISTS employees_qa
    PARTITION OF employees_partitioned FOR VALUES IN ('Quality Assurance');
  CREATE TABLE IF NOT EXISTS employees_support
    PARTITION OF employees_partitioned FOR VALUES IN ('Support');"

echo
echo "Inserting sample rows through the parent table (PostgreSQL routes them)..."
db_psql "$LAB_DB_NAME" -c "
  INSERT INTO employees_partitioned (first_name, last_name, department, email)
  SELECT v.first_name, v.last_name, v.department, v.email
  FROM (VALUES
    ('Ana',    'Ruiz',     'Sales',             'ana.ruiz@example.com'),
    ('Hugo',   'Navarro',  'Sales',             'hugo.navarro@example.com'),
    ('Diego',  'Salas',    'Engineering',       'diego.salas@example.com'),
    ('Marta',  'Pena',     'Marketing',         'marta.pena@example.com'),
    ('Luis',   'Ortega',   'Finance',           'luis.ortega@example.com'),
    ('Sara',   'Molina',   'HR',                'sara.molina@example.com'),
    ('Ivan',   'Castro',   'Quality Assurance', 'ivan.castro@example.com'),
    ('Nora',   'Vidal',    'Support',           'nora.vidal@example.com')
  ) AS v(first_name, last_name, department, email)
  WHERE NOT EXISTS (
    SELECT 1
    FROM employees_partitioned p
    WHERE p.email = v.email
  );"

if (( BULK )); then
  echo
  echo "Copying the employees rows through the parent table..."
  db_psql "$LAB_DB_NAME" -c "
    INSERT INTO employees_partitioned (
      first_name, last_name, department, department_id, email
    )
    SELECT e.first_name, e.last_name, e.department, e.department_id, e.email
    FROM employees e
    WHERE NOT EXISTS (
      SELECT 1
      FROM employees_partitioned p
      WHERE p.first_name = e.first_name
        AND p.last_name  = e.last_name
        AND p.department = e.department
        AND p.email      = e.email
    );"
fi

echo
echo "Rows per partition (tableoid names the physical table):"
db_psql "$LAB_DB_NAME" -c "
  SELECT tableoid::regclass AS partition, count(*) AS rows
  FROM employees_partitioned
  GROUP BY 1
  ORDER BY 1;"

echo
echo "Partition pruning: this plan only scans employees_sales."
db_psql "$LAB_DB_NAME" -c "
  EXPLAIN (COSTS OFF)
  SELECT * FROM employees_partitioned WHERE department = 'Sales';"

echo
echo "Partitioned table ready. Insert through the parent; reads can filter on department."
