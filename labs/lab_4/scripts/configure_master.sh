#!/usr/bin/env bash
# Configure the primary PostgreSQL instance for physical replication.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

compose_lab4 up -d "$LAB4_MASTER_SERVICE"
lab4_wait_ready "$LAB4_MASTER_SERVICE"

lab4_psql "$LAB4_MASTER_SERVICE" "$LAB4_DATABASE" -c \
  "DO \$\$ BEGIN
     IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$LAB4_REPLICATION_USER') THEN
       CREATE ROLE $LAB4_REPLICATION_USER WITH REPLICATION LOGIN PASSWORD '$LAB4_REPLICATION_PASSWORD';
     ELSE
       ALTER ROLE $LAB4_REPLICATION_USER WITH REPLICATION LOGIN PASSWORD '$LAB4_REPLICATION_PASSWORD';
     END IF;
   END \$\$;"
lab4_exec "$LAB4_MASTER_SERVICE" bash -ceu \
  "grep -Fqx 'host replication $LAB4_REPLICATION_USER 0.0.0.0/0 scram-sha-256' \"\$PGDATA/pg_hba.conf\" ||
   printf '%s\n' 'host replication $LAB4_REPLICATION_USER 0.0.0.0/0 scram-sha-256' >> \"\$PGDATA/pg_hba.conf\""
lab4_psql "$LAB4_MASTER_SERVICE" postgres -c "ALTER SYSTEM SET wal_level = 'replica';"
lab4_psql "$LAB4_MASTER_SERVICE" postgres -c "ALTER SYSTEM SET max_wal_senders = 10;"
lab4_psql "$LAB4_MASTER_SERVICE" postgres -c "ALTER SYSTEM SET wal_keep_size = '64MB';"
compose_lab4 restart "$LAB4_MASTER_SERVICE"
lab4_wait_ready "$LAB4_MASTER_SERVICE"

echo "Primary '$LAB4_MASTER_SERVICE' is configured for replication."
