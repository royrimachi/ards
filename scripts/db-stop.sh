#!/usr/bin/env bash
# scripts/db-stop.sh
# Stops the shared PostgreSQL instance. The container and its data volume are
# preserved, so the next start resumes with the same databases.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "$SCRIPT_DIR/lib/db.sh"

db_stop

echo "PostgreSQL stopped. Data is preserved in '$POSTGRES_DATA_DIR'."
