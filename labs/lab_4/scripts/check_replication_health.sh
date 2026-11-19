#!/usr/bin/env bash
# Check the primary and standby replication health.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

threshold="${LAB4_HEALTH_THRESHOLD_SECONDS:-10}"
interval="${LAB4_HEALTH_INTERVAL_SECONDS:-10}"
once=false

usage() {
  echo "Usage: $0 [--once] [--threshold SECONDS] [--interval SECONDS]" >&2
}

while (($# > 0)); do
  case "$1" in
    --once)
      once=true
      shift
      ;;
    --threshold)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      threshold="$2"
      shift 2
      ;;
    --interval)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      interval="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if ! [[ "$threshold" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
   ! [[ "$interval" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "error: threshold and interval must be non-negative numbers." >&2
  exit 2
fi

sql_quote() {
  local value="$1"
  printf "%s" "${value//\'/\'\'}"
}

alert() {
  local node="$1"
  local anomaly="$2"
  local details="$3"
  local escaped_node escaped_anomaly escaped_details

  escaped_node="$(sql_quote "$node")"
  escaped_anomaly="$(sql_quote "$anomaly")"
  escaped_details="$(sql_quote "$details")"
  echo "WARNING: $node: $anomaly - $details" >&2

  if ! lab4_psql "$LAB4_MASTER_SERVICE" "$LAB4_DATABASE" -q -c \
      "INSERT INTO replication_alerts (node_name, anomaly_type, details)
       VALUES ('$escaped_node', '$escaped_anomaly', '$escaped_details');" \
      >/dev/null 2>&1; then
    echo "WARNING: could not persist alert because the primary is unavailable." >&2
  fi
}

check_once() {
  local primary_status standby_status
  local primary_row receiver_row
  local state sync_state replay_lag reply_age
  local receiver_status receiver_age
  local anomaly_count=0

  primary_status="$(lab4_psql "$LAB4_MASTER_SERVICE" "$LAB4_DATABASE" -q -t -A \
    -c "SELECT 1;" 2>/dev/null)" || {
    alert "$LAB4_MASTER_SERVICE" "offline" "PostgreSQL did not accept a connection."
    return 0
  }

  if [[ "$primary_status" != "1" ]]; then
    alert "$LAB4_MASTER_SERVICE" "query_failure" "Unexpected readiness response: $primary_status"
  fi

  if ! lab4_psql "$LAB4_MASTER_SERVICE" "$LAB4_DATABASE" -q -f - \
      < "$SCRIPT_DIR/init_health.sql" >/dev/null 2>&1; then
    echo "WARNING: unable to ensure replication_alerts exists on the primary." >&2
  fi

  primary_row="$(lab4_psql "$LAB4_MASTER_SERVICE" "$LAB4_DATABASE" -q -t -A \
    -F '|' -c \
    "SELECT COALESCE(state, 'null'),
            COALESCE(sync_state, 'null'),
            COALESCE(EXTRACT(EPOCH FROM replay_lag), -1),
            COALESCE(EXTRACT(EPOCH FROM (clock_timestamp() - reply_time)), -1)
       FROM pg_stat_replication
      WHERE application_name <> '' OR client_addr IS NOT NULL
      ORDER BY pid
      LIMIT 1;" 2>/dev/null)" || primary_row=""

  if [[ -z "$primary_row" ]]; then
    alert "$LAB4_SLAVE_SERVICE" "not_connected" "No standby is reporting to pg_stat_replication."
    anomaly_count=$((anomaly_count + 1))
  else
    IFS='|' read -r state sync_state replay_lag reply_age <<< "$primary_row"

    [[ "$state" == "streaming" ]] ||
      { alert "$LAB4_SLAVE_SERVICE" "replication_not_streaming" "state=$state"; anomaly_count=$((anomaly_count + 1)); }
    if [[ "$replay_lag" != "-1" ]] && awk "BEGIN { exit !($replay_lag > $threshold) }"; then
      alert "$LAB4_SLAVE_SERVICE" "lag_exceeded" "replay lag is ${replay_lag}s (threshold ${threshold}s)"
      anomaly_count=$((anomaly_count + 1))
    fi
    if [[ "$reply_age" != "-1" ]] && awk "BEGIN { exit !($reply_age > $threshold) }"; then
      alert "$LAB4_SLAVE_SERVICE" "stale_replica" "last reply was ${reply_age}s ago (threshold ${threshold}s)"
      anomaly_count=$((anomaly_count + 1))
    fi
  fi

  standby_status="$(lab4_psql "$LAB4_SLAVE_SERVICE" "$LAB4_DATABASE" -q -t -A \
    -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'recovery' ELSE 'primary' END;" \
    2>/dev/null)" || {
    alert "$LAB4_SLAVE_SERVICE" "offline" "PostgreSQL did not accept a connection."
    return 0
  }

  if [[ "$standby_status" != "recovery" ]]; then
    alert "$LAB4_SLAVE_SERVICE" "not_in_recovery" "standby reports state=$standby_status"
    anomaly_count=$((anomaly_count + 1))
  fi

  receiver_row="$(lab4_psql "$LAB4_SLAVE_SERVICE" "$LAB4_DATABASE" -q -t -A \
    -F '|' -c \
    "SELECT COALESCE(status, 'null'),
            COALESCE(EXTRACT(EPOCH FROM (clock_timestamp() - latest_end_time)), -1)
       FROM pg_stat_wal_receiver
      LIMIT 1;" 2>/dev/null)" || receiver_row=""

  if [[ -z "$receiver_row" ]]; then
    alert "$LAB4_SLAVE_SERVICE" "wal_receiver_missing" "No WAL receiver is active."
    anomaly_count=$((anomaly_count + 1))
  else
    IFS='|' read -r receiver_status receiver_age <<< "$receiver_row"
    [[ "$receiver_status" == "streaming" ]] ||
      { alert "$LAB4_SLAVE_SERVICE" "wal_receiver_not_streaming" "status=$receiver_status"; anomaly_count=$((anomaly_count + 1)); }
    if [[ "$receiver_age" != "-1" ]] && awk "BEGIN { exit !($receiver_age > $threshold) }"; then
      alert "$LAB4_SLAVE_SERVICE" "wal_receiver_stale" "last WAL was received ${receiver_age}s ago (threshold ${threshold}s)"
      anomaly_count=$((anomaly_count + 1))
    fi
  fi

  if (( anomaly_count == 0 )); then
    echo "Replication healthy: primary and standby are connected and within the ${threshold}s threshold."
  fi
}

while true; do
  check_once
  $once && break
  sleep "$interval"
done
