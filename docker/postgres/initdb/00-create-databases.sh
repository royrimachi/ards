#!/usr/bin/env bash
# 00-create-databases.sh
# Runs inside the PostgreSQL container the first time the data volume is created.
#
# Creates every database listed in POSTGRES_DATABASES (comma-separated) so a
# fresh install already has one database per lab. Scripts can also create
# databases later with ./scripts/db-create.sh.

set -Eeuo pipefail

requested="${POSTGRES_DATABASES:-}"

if [[ -z "${requested//[[:space:]]/}" ]]; then
  echo "initdb: no extra databases requested."
  exit 0
fi

IFS=',' read -ra databases <<< "$requested"

for raw_name in "${databases[@]}"; do
  db_name="$(printf '%s' "$raw_name" | tr -d '[:space:]')"

  [[ -z "$db_name" ]] && continue

  if [[ ! "$db_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "initdb: ignoring invalid database name '$db_name'." >&2
    continue
  fi

  echo "initdb: ensuring database '$db_name' exists..."
  psql -v ON_ERROR_STOP=1 \
       --username "$POSTGRES_USER" \
       --dbname "$POSTGRES_DB" \
       -v db_name="$db_name" <<'SQL'
SELECT format('CREATE DATABASE %I', :'db_name')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\gexec
SQL
done

echo "initdb: databases ready."
