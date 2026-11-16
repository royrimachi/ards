#!/usr/bin/env bash
# Write on the primary and verify the row on the standby.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

lab4_wait_ready "$LAB4_MASTER_SERVICE"
lab4_wait_ready "$LAB4_SLAVE_SERVICE"
lab4_psql "$LAB4_MASTER_SERVICE" "$LAB4_DATABASE" <<'SQL'
CREATE TABLE IF NOT EXISTS replication_test (
  id SERIAL PRIMARY KEY,
  note TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
INSERT INTO replication_test (note) VALUES ('Hello from the master');
SQL

for _ in {1..30}; do
  if lab4_psql "$LAB4_SLAVE_SERVICE" "$LAB4_DATABASE" -q -t -A \
      -c "SELECT count(*) FROM replication_test WHERE note = 'Hello from the master';" \
      | grep -Eq '^[1-9][0-9]*$'; then
    echo "Replication verified: the standby contains the master's row."
    exit 0
  fi
  sleep 1
done

echo "error: replicated row was not visible on the standby within 30s." >&2
exit 1
