#!/usr/bin/env bash
# create_schema_postgres.sh [--reset]
# Creates lab 1's database and schema in the shared PostgreSQL service.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

usage() {
  echo "usage: $0 [--reset]" >&2
}

reset=false
while (( $# > 0 )); do
  case "$1" in
    --reset) reset=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage; exit 1 ;;
  esac
  shift
done

db_require_running

if $reset; then
  db_drop "$LAB_DB_NAME"
fi

db_create "$LAB_DB_NAME"
echo "Creating PostgreSQL schema in '$LAB_DB_NAME'..."
db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/create_schema_postgres.sql"
echo "PostgreSQL schema created in database '$LAB_DB_NAME'."
