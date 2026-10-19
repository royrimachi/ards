#!/usr/bin/env bash
# create_schema.sh [--reset]
# Creates lab_2's database and tables in the shared PostgreSQL instance.
#
#   --reset   Drop and recreate only the lab_2 database before creating tables.
#             Other databases in the shared instance are never touched.

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
    --reset)
      reset=true
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

if $reset; then
  db_drop "$LAB_DB_NAME"
fi

db_create "$LAB_DB_NAME"

echo "Creating database schema in '$LAB_DB_NAME'..."
db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/create_tables.sql"

echo "Schema created in database '$LAB_DB_NAME'."
