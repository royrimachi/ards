#!/usr/bin/env bash
# Start the shared MySQL service and wait until it accepts connections.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/mysql.sh
source "$SCRIPT_DIR/../../../scripts/lib/mysql.sh"

mysql_up
mysql_wait_ready

echo
echo "MySQL is ready on 127.0.0.1:${MYSQL_PORT} (database: ${MYSQL_DATABASE})."
mysql_status
