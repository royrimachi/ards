#!/usr/bin/env bash
# insert_data.sh [--force]
# Inserts the sample data into lab_2's database in the shared instance.
#
# By default the script skips the insert when the employees table already has
# rows, so it is safe to re-run.
#
#   --force   Insert the sample data even when rows already exist.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

usage() {
  echo "usage: $0 [--force]" >&2
}

force=false

while (( $# > 0 )); do
  case "$1" in
    --force)
      force=true
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
  shift
done

db_require_running
db_create "$LAB_DB_NAME"

if ! $force; then
  tables_ready="$(db_exec "$LAB_DB_NAME" \
    "SELECT to_regclass('public.employees') IS NOT NULL")"

  if [[ "$tables_ready" == "t" ]]; then
    rows="$(db_exec "$LAB_DB_NAME" "SELECT count(*) FROM employees")"

    if [[ "$rows" =~ ^[0-9]+$ ]] && (( rows > 0 )); then
      echo "Database '$LAB_DB_NAME' already contains $rows employees; skipping insert."
      echo "Use --force to append more data, or create_schema.sh --reset for a clean run."
      exit 0
    fi
  fi
fi

echo "Inserting sample data into '$LAB_DB_NAME'..."
db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/insert_data.sql"

echo "Data inserted."
