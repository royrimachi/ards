#!/usr/bin/env bash
# log_performance.sh [--repeat N] [--interval SECONDS] [--report]
# Runs the predefined critical queries with EXPLAIN ANALYZE and appends their
# metrics to performance_log.
#
#   --repeat N         Run the logger N times (default: 1).
#   --interval SECONDS Wait SECONDS between repeated runs (default: 0).
#   --report           Show the performance report instead of logging a run.
#
# The query list and JSON parsing live in performance_logging.sql; this script
# only orchestrates runs through the shared database layer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

usage() {
  echo "usage: $0 [--repeat N] [--interval SECONDS] [--report]" >&2
}

repeat=1
interval=0
report=false

while (( $# > 0 )); do
  case "$1" in
    --repeat)
      if (( $# < 2 )); then
        echo "error: --repeat requires a value" >&2
        usage
        exit 1
      fi
      repeat="$2"
      shift 2
      ;;
    --interval)
      if (( $# < 2 )); then
        echo "error: --interval requires a value" >&2
        usage
        exit 1
      fi
      interval="$2"
      shift 2
      ;;
    --report)
      report=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! "$repeat" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: --repeat must be a positive integer" >&2
  exit 1
fi

if [[ ! "$interval" =~ ^[0-9]+$ ]]; then
  echo "error: --interval must be a non-negative integer" >&2
  exit 1
fi

db_require_running

if $report; then
  if ! db_exists "$LAB_DB_NAME"; then
    echo "error: database '$LAB_DB_NAME' does not exist." >&2
    echo "       Create it with: $SCRIPT_DIR/create_schema.sh" >&2
    exit 1
  fi

  table_ready="$(db_exec "$LAB_DB_NAME" \
    "SELECT to_regclass('public.performance_log') IS NOT NULL")"

  if [[ "$table_ready" != "t" ]]; then
    echo "error: table 'performance_log' does not exist in '$LAB_DB_NAME'." >&2
    echo "       Create the schema first: $SCRIPT_DIR/create_schema.sh" >&2
    exit 1
  fi

  echo "Query performance report for '$LAB_DB_NAME':"
  echo
  db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/performance_report.sql"
  exit 0
fi

db_create "$LAB_DB_NAME"

tables_ready="$(db_exec "$LAB_DB_NAME" \
  "SELECT to_regclass('public.employees') IS NOT NULL
      AND to_regclass('public.departments') IS NOT NULL
      AND to_regclass('public.performance_log') IS NOT NULL")"

if [[ "$tables_ready" != "t" ]]; then
  echo "error: lab tables are missing in '$LAB_DB_NAME'." >&2
  echo "       Run: $SCRIPT_DIR/create_schema.sh" >&2
  echo "       Then: $SCRIPT_DIR/insert_data.sh" >&2
  exit 1
fi

employees="$(db_exec "$LAB_DB_NAME" "SELECT count(*) FROM employees")"
if [[ "$employees" == "0" ]]; then
  echo "warning: employees is empty; run $SCRIPT_DIR/insert_data.sh for meaningful metrics." >&2
fi

for ((run = 1; run <= repeat; run++)); do
  echo "Logging query performance (run $run/$repeat)..."
  db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/performance_logging.sql"

  if (( run < repeat && interval > 0 )); then
    sleep "$interval"
  fi
done

rows="$(db_exec "$LAB_DB_NAME" "SELECT count(*) FROM performance_log")"

echo
echo "performance_log now contains $rows row(s)."
echo "Latest rows:"
db_psql "$LAB_DB_NAME" -c "
  SELECT id,
         query_name,
         estimated_cost,
         actual_time,
         logged_at
  FROM performance_log
  ORDER BY id DESC
  LIMIT 5;"

echo
echo "Compare runs with: $0 --report"
