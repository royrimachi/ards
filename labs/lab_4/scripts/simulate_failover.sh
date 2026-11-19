#!/usr/bin/env bash
# Stop the primary and promote the standby.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

compose_lab4 stop "$LAB4_MASTER_SERVICE"
lab4_psql "$LAB4_SLAVE_SERVICE" "$LAB4_DATABASE" -c "SELECT pg_promote();"
for _ in {1..30}; do
  if [[ "$(lab4_psql "$LAB4_SLAVE_SERVICE" "$LAB4_DATABASE" -q -t -A \
      -c "SELECT pg_is_in_recovery();")" == "f" ]]; then
    echo "Failover complete: the standby has been promoted."
    exit 0
  fi
  sleep 1
done

echo "error: standby promotion did not complete within 30s." >&2
exit 1
