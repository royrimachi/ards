#!/usr/bin/env bash
# Run metadata queries for lab 1's MySQL schema.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/mysql.sh
source "$SCRIPT_DIR/../../../scripts/lib/mysql.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

mysql_require_running
mysql_root_exec "CREATE DATABASE IF NOT EXISTS \`$LAB_DB_NAME\`"
mysql_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/metadata_queries.sql"
