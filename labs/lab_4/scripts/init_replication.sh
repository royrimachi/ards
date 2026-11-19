#!/usr/bin/env bash
# Initialize the standby from a fresh physical backup of the primary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

"$SCRIPT_DIR/configure_master.sh"
compose_lab4 stop "$LAB4_SLAVE_SERVICE" >/dev/null 2>&1 || true
compose_lab4 rm -f "$LAB4_SLAVE_SERVICE" >/dev/null 2>&1 || true
compose_lab4 run --rm --no-deps --entrypoint bash "$LAB4_SLAVE_SERVICE" -ceu \
  "rm -rf \"\$PGDATA\"/*;
   export PGPASSWORD='$LAB4_REPLICATION_PASSWORD';
   pg_basebackup -h '$LAB4_MASTER_SERVICE' -D \"\$PGDATA\" -U '$LAB4_REPLICATION_USER' -Fp -Xs -P -R"
compose_lab4 up -d "$LAB4_SLAVE_SERVICE"
"$SCRIPT_DIR/configure_slave.sh"

echo "Streaming replication initialized."
