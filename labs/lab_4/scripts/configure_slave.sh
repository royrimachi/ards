#!/usr/bin/env bash
# Verify that the standby is running and following the primary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

lab4_wait_ready "$LAB4_SLAVE_SERVICE"
state="$(lab4_psql "$LAB4_SLAVE_SERVICE" "$LAB4_DATABASE" -q -t -A -c "SELECT pg_is_in_recovery();")"

if [[ "$state" != "t" ]]; then
  echo "error: $LAB4_SLAVE_SERVICE is not in recovery mode." >&2
  return 1 2>/dev/null || exit 1
fi

echo "Standby '$LAB4_SLAVE_SERVICE' is following the primary."
