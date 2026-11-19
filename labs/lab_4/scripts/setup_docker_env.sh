#!/usr/bin/env bash
# Start the isolated Docker network and primary service for lab 4.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

compose_lab4 pull "$LAB4_MASTER_SERVICE" "$LAB4_SLAVE_SERVICE"
compose_lab4 up -d "$LAB4_MASTER_SERVICE"
lab4_wait_ready "$LAB4_MASTER_SERVICE"
echo "Lab 4 primary environment is ready."
