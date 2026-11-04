#!/usr/bin/env bash
# insert_data.sh [--force]
# Inserts lab 1's sample data. Re-running is safe unless --force is supplied.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/mysql.sh
source "$SCRIPT_DIR/../../../scripts/lib/mysql.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

usage() {
  echo "usage: $0 [--force]" >&2
}

force=false
while (( $# > 0 )); do
  case "$1" in
    --force) force=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage; exit 1 ;;
  esac
  shift
done

mysql_require_running
mysql_root_exec "CREATE DATABASE IF NOT EXISTS \`$LAB_DB_NAME\`"

if ! $force; then
  tables_ready="$(mysql_exec "$LAB_DB_NAME" \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$LAB_DB_NAME' AND table_name = 'employees'")"
  if [[ "$tables_ready" == "1" ]]; then
    rows="$(mysql_exec "$LAB_DB_NAME" "SELECT COUNT(*) FROM employees")"
    if [[ "$rows" =~ ^[0-9]+$ ]] && (( rows > 0 )); then
      echo "Database '$LAB_DB_NAME' already contains $rows employees; skipping insert."
      echo "Use --force to append more data, or create_schema.sh --reset for a clean run."
      exit 0
    fi
  fi
fi

echo "Inserting sample data into '$LAB_DB_NAME'..."
mysql_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/insert_data.sql"
echo "Data inserted."
