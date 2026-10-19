#!/usr/bin/env bash
# scripts/lib/db.sh
# Shared database access layer for every lab in the project.
#
# Usage (from any script):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/../../scripts/lib/db.sh"
#
# The library:
#   - resolves the project root and loads .env,
#   - runs Docker Compose against the shared PostgreSQL service,
#   - exposes db_* helpers that always target a service name, never a container
#     name or a fixed database.
#
# Labs should use these helpers instead of calling docker/docker compose or
# psql directly.

if [[ -n "${__ARDS_DB_SH_LOADED:-}" ]]; then
  return 0
fi
__ARDS_DB_SH_LOADED=1

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/compose.yaml"
ENV_FILE="$PROJECT_ROOT/.env"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "error: compose file not found at $COMPOSE_FILE" >&2
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  echo "warning: $ENV_FILE not found; using defaults. Copy .env.example to .env." >&2
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DATABASES="${POSTGRES_DATABASES:-}"
POSTGRES_DATA_DIR="${POSTGRES_DATA_DIR:-./data/postgres}"
DB_SERVICE="${DB_SERVICE:-postgres}"
DB_READY_TIMEOUT="${DB_READY_TIMEOUT:-60}"

# Resolve the data directory against the project root so scripts behave the
# same from any working directory.
if [[ "$POSTGRES_DATA_DIR" != /* ]]; then
  POSTGRES_DATA_DIR="$PROJECT_ROOT/${POSTGRES_DATA_DIR#./}"
fi

# compose <args...>
# Runs Docker Compose from the project root with the project .env file.
compose() {
  local args=(docker compose --project-directory "$PROJECT_ROOT" -f "$COMPOSE_FILE")
  if [[ -f "$ENV_FILE" ]]; then
    args+=(--env-file "$ENV_FILE")
  fi
  "${args[@]}" "$@"
}

# db_validate_name <database>
db_validate_name() {
  local db_name="$1"
  if [[ ! "$db_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "error: invalid database name '$db_name' (letters, digits and underscores only)." >&2
    return 1
  fi
}

# db_up
# Starts the shared service and waits until it is healthy.
db_up() {
  mkdir -p "$POSTGRES_DATA_DIR"
  compose up -d --wait "$DB_SERVICE"
}

# db_stop
# Stops the shared service, preserving the container and its data volume.
db_stop() {
  compose stop "$DB_SERVICE"
}

# db_status
# Shows the Compose status of the shared service.
db_status() {
  compose ps "$DB_SERVICE"
}

# db_is_running
# Succeeds when the shared service is running.
db_is_running() {
  compose ps --status running --services 2>/dev/null | grep -qx "$DB_SERVICE"
}

# db_require_running
# Fails with a helpful message when the shared service is not running.
db_require_running() {
  if ! db_is_running; then
    echo "error: the '$DB_SERVICE' service is not running." >&2
    echo "       Start it with: $PROJECT_ROOT/scripts/db-up.sh" >&2
    return 1
  fi
}

# db_wait_ready
# Waits until PostgreSQL accepts connections.
db_wait_ready() {
  local elapsed=0

  until compose exec -T "$DB_SERVICE" \
        pg_isready -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
    if (( elapsed >= DB_READY_TIMEOUT )); then
      echo "error: PostgreSQL did not become ready within ${DB_READY_TIMEOUT}s." >&2
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
}

# db_psql <database> [psql arguments...]
# Runs psql inside the container, non-interactively and fail-fast.
db_psql() {
  local db_name="$1"
  shift

  db_validate_name "$db_name"
  compose exec -T "$DB_SERVICE" \
    psql -v ON_ERROR_STOP=1 -X -U "$POSTGRES_USER" -d "$db_name" "$@"
}

# db_exec <database> <sql>
# Runs a single SQL statement and returns unaligned, tuple-only output.
db_exec() {
  local db_name="$1"
  local sql="$2"

  db_psql "$db_name" -q -t -A -c "$sql"
}

# db_exists <database>
# Succeeds when the database exists.
db_exists() {
  local db_name="$1"
  db_validate_name "$db_name"

  [[ "$(db_exec "$POSTGRES_DB" "SELECT 1 FROM pg_database WHERE datname = '$db_name'")" == "1" ]]
}

# db_create <database>
# Creates the database when it does not exist yet (idempotent).
db_create() {
  local db_name="$1"
  db_validate_name "$db_name"

  if db_exists "$db_name"; then
    echo "Database '$db_name' already exists."
    return 0
  fi

  echo "Creating database '$db_name'..."
  db_psql "$POSTGRES_DB" -q -c "CREATE DATABASE \"$db_name\""
}

# db_drop <database>
# Drops the database and any open connections (idempotent).
db_drop() {
  local db_name="$1"
  db_validate_name "$db_name"

  case "$db_name" in
    postgres|template0|template1)
      echo "error: refusing to drop protected database '$db_name'." >&2
      return 1
      ;;
  esac

  echo "Dropping database '$db_name'..."
  db_psql "$POSTGRES_DB" -q -c "DROP DATABASE IF EXISTS \"$db_name\" WITH (FORCE)"
}

# db_run_sql_file <database> <file>
# Streams a .sql file into psql. No docker cp and no CWD dependency.
db_run_sql_file() {
  local db_name="$1"
  local sql_file="$2"

  if [[ ! -f "$sql_file" ]]; then
    echo "error: SQL file not found: $sql_file" >&2
    return 1
  fi

  db_psql "$db_name" -q -f - < "$sql_file"
}

# db_shell [database]
# Opens an interactive psql session (defaults to the maintenance database).
db_shell() {
  local db_name="${1:-$POSTGRES_DB}"
  db_validate_name "$db_name"

  compose exec "$DB_SERVICE" \
    psql -X -U "$POSTGRES_USER" -d "$db_name"
}

# db_list
# Lists non-template databases, one per line.
db_list() {
  db_exec "$POSTGRES_DB" \
    "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname"
}

# db_ensure_configured_databases
# Makes sure every database listed in POSTGRES_DATABASES exists. Useful after
# starting an existing volume, where initdb scripts are not re-executed.
db_ensure_configured_databases() {
  local raw_name db_name
  local -a databases

  IFS=',' read -ra databases <<< "$POSTGRES_DATABASES"

  for raw_name in "${databases[@]}"; do
    db_name="$(printf '%s' "$raw_name" | tr -d '[:space:]')"
    [[ -z "$db_name" ]] && continue
    db_create "$db_name"
  done
}
