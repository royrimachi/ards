#!/usr/bin/env bash
# Shared helpers for lab 4's isolated Compose project.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

compose_lab4() {
  docker compose \
    --project-directory "$PROJECT_ROOT" \
    --project-name "$LAB4_PROJECT_NAME" \
    -f "$LAB4_COMPOSE_FILE" \
    "$@"
}

lab4_exec() {
  local service="$1"
  shift
  compose_lab4 exec -T "$service" "$@"
}

lab4_psql() {
  local service="$1"
  local database="$2"
  shift 2
  lab4_exec "$service" psql -v ON_ERROR_STOP=1 -X -U postgres -d "$database" "$@"
}

lab4_wait_ready() {
  local service="$1"
  local elapsed=0
  until compose_lab4 exec -T "$service" pg_isready -U postgres -d "$LAB4_DATABASE" >/dev/null 2>&1; do
    if (( elapsed >= 60 )); then
      echo "error: $service did not become ready within 60s." >&2
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
}
