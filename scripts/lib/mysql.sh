#!/usr/bin/env bash
# scripts/lib/mysql.sh
# Shared MySQL access layer for labs that use the project-wide MySQL service.

if [[ -n "${__ARDS_MYSQL_SH_LOADED:-}" ]]; then
  return 0
fi
__ARDS_MYSQL_SH_LOADED=1

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

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_DATABASE="${MYSQL_DATABASE:-demo_db}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATA_DIR="${MYSQL_DATA_DIR:-./data/mysql}"
MYSQL_SERVICE="${MYSQL_SERVICE:-mysql}"
MYSQL_READY_TIMEOUT="${MYSQL_READY_TIMEOUT:-60}"

if [[ "$MYSQL_DATA_DIR" != /* ]]; then
  MYSQL_DATA_DIR="$PROJECT_ROOT/${MYSQL_DATA_DIR#./}"
fi

compose_mysql() {
  local args=(docker compose --project-directory "$PROJECT_ROOT" -f "$COMPOSE_FILE")
  if [[ -f "$ENV_FILE" ]]; then
    args+=(--env-file "$ENV_FILE")
  fi
  "${args[@]}" "$@"
}

mysql_validate_name() {
  local db_name="$1"
  if [[ ! "$db_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "error: invalid database name '$db_name' (letters, digits and underscores only)." >&2
    return 1
  fi
}

mysql_up() {
  mkdir -p "$MYSQL_DATA_DIR"
  compose_mysql up -d --wait "$MYSQL_SERVICE"
}

mysql_stop() {
  compose_mysql stop "$MYSQL_SERVICE"
}

mysql_status() {
  compose_mysql ps "$MYSQL_SERVICE"
}

mysql_is_running() {
  compose_mysql ps --status running --services 2>/dev/null | grep -qx "$MYSQL_SERVICE"
}

mysql_require_running() {
  if ! mysql_is_running; then
    echo "error: the '$MYSQL_SERVICE' service is not running." >&2
    echo "       Start it with: $PROJECT_ROOT/labs/lab_1/scripts/start_container.sh" >&2
    return 1
  fi
}

mysql_wait_ready() {
  local elapsed=0

  until compose_mysql exec -T "$MYSQL_SERVICE" \
      mysqladmin ping -h localhost -u root -p"$MYSQL_ROOT_PASSWORD" --silent >/dev/null 2>&1; do
    if (( elapsed >= MYSQL_READY_TIMEOUT )); then
      echo "error: MySQL did not become ready within ${MYSQL_READY_TIMEOUT}s." >&2
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
}

mysql_exec() {
  local db_name="$1"
  local sql="$2"

  mysql_validate_name "$db_name"
  compose_mysql exec -T "$MYSQL_SERVICE" \
    mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" "$db_name" \
    -e "$sql"
}

mysql_root_exec() {
  local sql="$1"

  compose_mysql exec -T "$MYSQL_SERVICE" \
    mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" \
    -e "$sql"
}

mysql_run_sql_file() {
  local db_name="$1"
  local sql_file="$2"

  mysql_validate_name "$db_name"
  if [[ ! -f "$sql_file" ]]; then
    echo "error: SQL file not found: $sql_file" >&2
    return 1
  fi

  compose_mysql exec -T "$MYSQL_SERVICE" \
    mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$db_name" < "$sql_file"
}

mysql_shell() {
  local db_name="${1:-$MYSQL_DATABASE}"
  mysql_validate_name "$db_name"
  compose_mysql exec "$MYSQL_SERVICE" \
    mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$db_name"
}
