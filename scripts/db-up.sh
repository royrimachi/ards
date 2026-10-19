#!/usr/bin/env bash
# scripts/db-up.sh
# Starts the shared PostgreSQL instance and ensures every configured lab
# database exists. Safe to run repeatedly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "$SCRIPT_DIR/lib/db.sh"

db_up
db_wait_ready
db_ensure_configured_databases

echo
echo "PostgreSQL is ready on 127.0.0.1:${POSTGRES_PORT} (user: ${POSTGRES_USER})."
db_status
