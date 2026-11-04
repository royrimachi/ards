#!/usr/bin/env bash
# Run PostgreSQL metadata queries for lab 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

db_require_running
db_create "$LAB_DB_NAME"
db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/metadata_queries_postgres.sql"
