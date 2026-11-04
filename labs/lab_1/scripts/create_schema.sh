#!/usr/bin/env bash
# create_schema.sh [--reset]
# Creates lab 1's database and schema in the shared MySQL service.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/mysql.sh
source "$SCRIPT_DIR/../../../scripts/lib/mysql.sh"
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

mysql_require_running

if $reset; then
  mysql_root_exec "DROP DATABASE IF EXISTS \`$LAB_DB_NAME\`"
fi

mysql_root_exec "CREATE DATABASE IF NOT EXISTS \`$LAB_DB_NAME\`"
echo "Creating database schema in '$LAB_DB_NAME'..."
mysql_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/create_schema.sql"
echo "Schema created in database '$LAB_DB_NAME'."
