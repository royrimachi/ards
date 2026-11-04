#!/usr/bin/env bash
# Stop the shared MySQL service while preserving its data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/mysql.sh
source "$SCRIPT_DIR/../../../scripts/lib/mysql.sh"

mysql_stop
