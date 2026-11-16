#!/usr/bin/env bash
# Start the lab 4 standby service after replication has been initialized.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

compose_lab4 up -d "$LAB4_SLAVE_SERVICE"
lab4_wait_ready "$LAB4_SLAVE_SERVICE"
echo "Slave is ready on port ${LAB4_SLAVE_PORT:-55433}."
