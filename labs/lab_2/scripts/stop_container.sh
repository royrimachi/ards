#!/usr/bin/env bash
# stop_container.sh
# Stops the shared PostgreSQL instance while preserving the container and its
# data volume. Other labs keep their databases too.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"

echo "Stopping the shared PostgreSQL container..."
db_stop

echo "Container stopped. Data is preserved; restart with start_container.sh."
