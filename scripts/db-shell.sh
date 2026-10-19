#!/usr/bin/env bash
# scripts/db-shell.sh [database]
# Opens an interactive psql session against the shared instance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "$SCRIPT_DIR/lib/db.sh"

if (( $# > 1 )); then
  echo "usage: $0 [database]" >&2
  exit 1
fi

db_require_running
db_shell "${1:-}"
