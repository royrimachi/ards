#!/usr/bin/env bash
# Start the lab 4 primary service.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

compose_lab4 up -d "$LAB4_MASTER_SERVICE"
lab4_wait_ready "$LAB4_MASTER_SERVICE"
echo "Master is ready on port ${LAB4_MASTER_PORT:-55432}."
