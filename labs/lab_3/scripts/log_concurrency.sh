#!/usr/bin/env bash
# labs/lab_3/scripts/log_concurrency.sh
# Runs concurrent transactions, detects lock waits, lock timeouts and
# deadlocks, and records each event in concurrency_log.
#
#   --scenario all|lock-wait|lock-timeout|deadlock
#       Scenario to run (default: all).
#   --isolation LEVEL
#       Transaction isolation level. Accepts READ COMMITTED, REPEATABLE READ
#       or SERIALIZABLE (default: READ COMMITTED).
#   --report
#       Show the concurrency report instead of running scenarios.
#   --minutes N
#       Lookback window for --report (default: 60).
#
# Examples:
#   ./log_concurrency.sh
#   ./log_concurrency.sh --scenario deadlock
#   ./log_concurrency.sh --isolation "REPEATABLE READ"
#   ./log_concurrency.sh --report --minutes 15

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

usage() {
  echo "usage: $0 [--scenario all|lock-wait|lock-timeout|deadlock]" >&2
  echo "          [--isolation 'READ COMMITTED'|'REPEATABLE READ'|'SERIALIZABLE']" >&2
  echo "          [--report [--minutes N]]" >&2
}

die() {
  echo "error: $*" >&2
  exit 1
}

scenario="all"
isolation="READ COMMITTED"
report=false
minutes=60

while (( $# > 0 )); do
  case "$1" in
    --scenario)
      (( $# >= 2 )) || die "--scenario requires a value"
      scenario="$2"
      shift 2
      ;;
    --isolation)
      (( $# >= 2 )) || die "--isolation requires a value"
      isolation="$2"
      shift 2
      ;;
    --report)
      report=true
      shift
      ;;
    --minutes)
      (( $# >= 2 )) || die "--minutes requires a value"
      minutes="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "unknown option '$1'"
      ;;
  esac
done

case "$scenario" in
  all|lock-wait|lock-timeout|deadlock) ;;
  *) die "unknown scenario '$scenario' (use all, lock-wait, lock-timeout or deadlock)" ;;
esac

if [[ ! "$minutes" =~ ^[1-9][0-9]*$ ]]; then
  die "--minutes must be a positive integer"
fi

isolation="$(printf '%s' "$isolation" | tr '[:lower:]' '[:upper:]')"
case "$isolation" in
  "READ COMMITTED"|"REPEATABLE READ"|"SERIALIZABLE") ;;
  *) die "unsupported isolation level '$isolation'" ;;
esac

require_lab_database() {
  db_require_running
  db_wait_ready

  if ! db_exists "$LAB_DB_NAME"; then
    echo "error: database '$LAB_DB_NAME' does not exist." >&2
    echo "       Create it with: $SCRIPT_DIR/create_db_env.sh" >&2
    return 1
  fi
}

require_log_table() {
  local table_ready
  table_ready="$(db_exec "$LAB_DB_NAME" \
    "SELECT to_regclass('public.concurrency_log') IS NOT NULL")"

  if [[ "$table_ready" != "t" ]]; then
    echo "error: table 'concurrency_log' does not exist in '$LAB_DB_NAME'." >&2
    echo "       Create it with: $SCRIPT_DIR/create_db_env.sh" >&2
    return 1
  fi
}

run_report() {
  require_lab_database
  require_log_table

  echo "Concurrency conflict report for '$LAB_DB_NAME' (last $minutes minute(s)):"
  db_psql "$LAB_DB_NAME" -v "minutes=$minutes" -q -f - \
    < "$SCRIPT_DIR/concurrency_report.sql"
}

if $report; then
  run_report
  exit 0
fi

# Ensure the schema, seed rows and logging functions exist before running.
db_require_running
db_wait_ready
if ! db_exists "$LAB_DB_NAME"; then
  db_create "$LAB_DB_NAME"
fi
db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/init_db.sql"
db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/concurrency_logging.sql"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/ards-lab3.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

run_id="$(date +%s)_$$"
new_app_name() {
  local scenario_name="$1"
  local role="$2"
  printf 'ards_lab3_%s_%s_%s' "${scenario_name//-/_}" "$role" "$run_id"
}

# Finds the backend PID of a session that has taken its first lock and is now
# sleeping in pg_sleep. This makes the harness wait for real readiness instead
# of guessing with a fixed delay.
wait_for_session_pid() {
  local app_name="$1"
  local timeout_seconds="${2:-10}"
  local elapsed=0
  local pid=""

  while (( elapsed < timeout_seconds * 10 )); do
    pid="$(db_exec "$LAB_DB_NAME" "
      SELECT pid
      FROM pg_stat_activity
      WHERE application_name = '$app_name'
        AND wait_event = 'PgSleep'
      ORDER BY backend_start DESC
      LIMIT 1")"

    if [[ -n "$pid" ]]; then
      printf '%s\n' "$pid"
      return 0
    fi

    sleep 0.1
    elapsed=$((elapsed + 1))
  done

  return 1
}

SESSION_PID=""

# Starts a background psql session that:
#   1. locks first_owner with SELECT ... FOR UPDATE,
#   2. sleeps, holding the lock,
#   3. optionally locks second_owner (used to form the deadlock cycle),
#   4. commits.
start_session() {
  local app_name="$1"
  local first_owner="$2"
  local second_owner="$3"
  local hold_seconds="$4"
  local session_isolation="$5"
  local deadlock_timeout="$6"
  local stdout_file="$7"
  local stderr_file="$8"

  db_psql "$LAB_DB_NAME" -q -t -A -v ON_ERROR_STOP=1 \
    -v "app_name=$app_name" \
    -v "first_owner=$first_owner" \
    -v "second_owner=$second_owner" \
    -v "hold_seconds=$hold_seconds" \
    -v "isolation=$session_isolation" \
    -v "deadlock_timeout=$deadlock_timeout" \
    -f - >"$stdout_file" 2>"$stderr_file" <<'SQL' &
SET application_name = :'app_name';
SET deadlock_timeout = :'deadlock_timeout';
BEGIN ISOLATION LEVEL :isolation;
SELECT id FROM account WHERE owner_name = :'first_owner' FOR UPDATE;
SELECT pg_sleep(:hold_seconds);
SELECT id FROM account WHERE owner_name = :'second_owner' FOR UPDATE;
COMMIT;
SQL

  SESSION_PID=$!
}

extract_marker() {
  local file="$1"
  local marker="$2"
  local line

  line="$(grep -E "^${marker}=" "$file" 2>/dev/null | tail -n 1 || true)"
  printf '%s' "${line#${marker}=}"
}

run_lock_wait() {
  local holder_app waiter_app holder_shell_pid blocker_pid
  local waiter_out="$tmpdir/lock_wait_waiter.out"
  local waiter_err="$tmpdir/lock_wait_waiter.err"
  local event_id wait_ms

  echo "========================================"
  echo " Lock wait scenario"
  echo "========================================"
  echo "Isolation level: $isolation"
  echo "The holder locks Alice's row for 3 seconds."
  echo "The waiter tries to lock the same row and records the wait."
  echo

  holder_app="$(new_app_name lock-wait holder)"
  start_session "$holder_app" "Alice" "Alice" 3 "$isolation" "500ms" \
    "$tmpdir/lock_wait_holder.out" "$tmpdir/lock_wait_holder.err"
  holder_shell_pid=$SESSION_PID

  if ! blocker_pid="$(wait_for_session_pid "$holder_app" 10)"; then
    echo "error: the lock holder did not become ready." >&2
    cat "$tmpdir/lock_wait_holder.err" >&2 || true
    wait "$holder_shell_pid" || true
    return 1
  fi

  echo "Holder backend PID: $blocker_pid"
  echo "Waiting for the lock..."

  waiter_app="$(new_app_name lock-wait waiter)"
  if ! db_psql "$LAB_DB_NAME" -q -t -A -v ON_ERROR_STOP=1 \
        -v "app_name=$waiter_app" \
        -v "isolation=$isolation" \
        -v "blocker_pid=$blocker_pid" \
        -v "holder_app=$holder_app" \
        -f - >"$waiter_out" 2>"$waiter_err" <<'SQL'
SET application_name = :'app_name';
BEGIN ISOLATION LEVEL :isolation;
SELECT event_log_id, observed_wait_ms
FROM demo_lock_wait_probe('Alice', :'blocker_pid'::int, :'holder_app')
\gset
\echo LAB3_EVENT_LOG_ID=:event_log_id
\echo LAB3_WAIT_MS=:observed_wait_ms
COMMIT;
SQL
  then
    echo "error: the lock waiter failed." >&2
    cat "$waiter_err" >&2 || true
    wait "$holder_shell_pid" || true
    return 1
  fi

  if ! wait "$holder_shell_pid"; then
    echo "error: the lock holder failed." >&2
    cat "$tmpdir/lock_wait_holder.err" >&2 || true
    return 1
  fi

  event_id="$(extract_marker "$waiter_out" "LAB3_EVENT_LOG_ID")"
  wait_ms="$(extract_marker "$waiter_out" "LAB3_WAIT_MS")"

  echo "Waiter observed a wait of ${wait_ms:-?} ms."
  if [[ -n "$event_id" ]]; then
    echo "Logged lock_wait event #$event_id."
  else
    echo "warning: no lock_wait event was logged (wait was below the threshold)." >&2
  fi
  echo
}

run_lock_timeout() {
  local holder_app waiter_app holder_shell_pid blocker_pid
  local waiter_out="$tmpdir/lock_timeout_waiter.out"
  local waiter_err="$tmpdir/lock_timeout_waiter.err"
  local event_id wait_ms

  echo "========================================"
  echo " Lock timeout scenario"
  echo "========================================"
  echo "Isolation level: $isolation"
  echo "The holder locks Alice's row for 3 seconds."
  echo "The waiter uses lock_timeout = 1s and records SQLSTATE 55P03."
  echo

  holder_app="$(new_app_name lock-timeout holder)"
  start_session "$holder_app" "Alice" "Alice" 3 "$isolation" "500ms" \
    "$tmpdir/lock_timeout_holder.out" "$tmpdir/lock_timeout_holder.err"
  holder_shell_pid=$SESSION_PID

  if ! blocker_pid="$(wait_for_session_pid "$holder_app" 10)"; then
    echo "error: the lock holder did not become ready." >&2
    cat "$tmpdir/lock_timeout_holder.err" >&2 || true
    wait "$holder_shell_pid" || true
    return 1
  fi

  echo "Holder backend PID: $blocker_pid"
  echo "Waiting for the 1-second lock timeout..."

  waiter_app="$(new_app_name lock-timeout waiter)"
  if ! db_psql "$LAB_DB_NAME" -q -t -A -v ON_ERROR_STOP=1 \
        -v "app_name=$waiter_app" \
        -v "isolation=$isolation" \
        -v "blocker_pid=$blocker_pid" \
        -v "holder_app=$holder_app" \
        -f - >"$waiter_out" 2>"$waiter_err" <<'SQL'
SET application_name = :'app_name';
BEGIN ISOLATION LEVEL :isolation;
SELECT event_log_id, observed_wait_ms
FROM demo_lock_timeout_probe('Alice', 1000, :'blocker_pid'::int, :'holder_app')
\gset
\echo LAB3_EVENT_LOG_ID=:event_log_id
\echo LAB3_WAIT_MS=:observed_wait_ms
COMMIT;
SQL
  then
    echo "error: the lock timeout waiter failed." >&2
    cat "$waiter_err" >&2 || true
    wait "$holder_shell_pid" || true
    return 1
  fi

  if ! wait "$holder_shell_pid"; then
    echo "error: the lock holder failed." >&2
    cat "$tmpdir/lock_timeout_holder.err" >&2 || true
    return 1
  fi

  event_id="$(extract_marker "$waiter_out" "LAB3_EVENT_LOG_ID")"
  wait_ms="$(extract_marker "$waiter_out" "LAB3_WAIT_MS")"

  echo "Waiter was blocked for ${wait_ms:-?} ms and timed out."
  if [[ -n "$event_id" ]]; then
    echo "Logged lock_timeout event #$event_id (SQLSTATE 55P03)."
  else
    echo "warning: no lock_timeout event was logged." >&2
  fi
  echo
}

run_deadlock() {
  local app_a app_b holder_shell_a holder_shell_b
  local backend_a backend_b
  local status_a=0 status_b=0
  local victim_app victim_err victim_pid victim_status
  local blocker_app blocker_pid blocker_status log_id

  echo "========================================"
  echo " Deadlock scenario"
  echo "========================================"
  echo "Isolation level: $isolation"
  echo "Session A locks Alice then Bob; session B locks Bob then Alice."
  echo "PostgreSQL detects the cycle and aborts one transaction."
  echo

  app_a="$(new_app_name deadlock a)"
  start_session "$app_a" "Alice" "Bob" 3 "$isolation" "500ms" \
    "$tmpdir/deadlock_a.out" "$tmpdir/deadlock_a.err"
  holder_shell_a=$SESSION_PID

  if ! backend_a="$(wait_for_session_pid "$app_a" 10)"; then
    echo "error: deadlock session A did not become ready." >&2
    cat "$tmpdir/deadlock_a.err" >&2 || true
    wait "$holder_shell_a" || true
    return 1
  fi

  app_b="$(new_app_name deadlock b)"
  start_session "$app_b" "Bob" "Alice" 3 "$isolation" "500ms" \
    "$tmpdir/deadlock_b.out" "$tmpdir/deadlock_b.err"
  holder_shell_b=$SESSION_PID

  if ! backend_b="$(wait_for_session_pid "$app_b" 10)"; then
    echo "error: deadlock session B did not become ready." >&2
    cat "$tmpdir/deadlock_b.err" >&2 || true
    wait "$holder_shell_b" || true
    wait "$holder_shell_a" || true
    return 1
  fi

  echo "Session A backend PID: $backend_a"
  echo "Session B backend PID: $backend_b"
  echo "Waiting for PostgreSQL deadlock detection..."

  wait "$holder_shell_a" || status_a=$?
  wait "$holder_shell_b" || status_b=$?

  if grep -q 'deadlock detected' "$tmpdir/deadlock_a.err" 2>/dev/null; then
    victim_app="$app_a"
    victim_err="$tmpdir/deadlock_a.err"
    victim_pid="$backend_a"
    victim_status="$status_a"
    blocker_app="$app_b"
    blocker_pid="$backend_b"
    blocker_status="$status_b"
  elif grep -q 'deadlock detected' "$tmpdir/deadlock_b.err" 2>/dev/null; then
    victim_app="$app_b"
    victim_err="$tmpdir/deadlock_b.err"
    victim_pid="$backend_b"
    victim_status="$status_b"
    blocker_app="$app_a"
    blocker_pid="$backend_a"
    blocker_status="$status_a"
  else
    echo "error: no deadlock was detected; inspect the session errors." >&2
    echo "--- session A stderr ---" >&2
    cat "$tmpdir/deadlock_a.err" >&2 || true
    echo "--- session B stderr ---" >&2
    cat "$tmpdir/deadlock_b.err" >&2 || true
    return 1
  fi

  echo "Victim session: $victim_app"
  grep -m 1 -E 'ERROR:.*deadlock detected' "$victim_err" || true

  log_id="$(db_psql "$LAB_DB_NAME" -q -t -A -v ON_ERROR_STOP=1 \
    -v "isolation=$isolation" \
    -v "victim_app=$victim_app" \
    -v "blocker_app=$blocker_app" \
    -v "victim_pid=$victim_pid" \
    -v "blocker_pid=$blocker_pid" \
    -v "victim_status=$victim_status" \
    -v "blocker_status=$blocker_status" \
    -f - <<'SQL'
SELECT log_concurrency_event(
    'deadlock',
    :'isolation',
    'account: rows owner_name=Alice and owner_name=Bob',
    p_table_name => 'account',
    p_row_info => 'owner_name in (Alice, Bob)',
    p_error_code => '40P01',
    p_backend_pid => :'victim_pid'::int,
    p_blocking_pid => :'blocker_pid'::int,
    p_details => jsonb_build_object(
        'victim_application_name', :'victim_app',
        'blocker_application_name', :'blocker_app',
        'victim_exit_status', :'victim_status'::int,
        'blocker_exit_status', :'blocker_status'::int
    ),
    p_scenario => 'deadlock'
);
SQL
  )"
  log_id="$(printf '%s' "$log_id" | tr -d '[:space:]')"

  echo "Logged deadlock event #$log_id (SQLSTATE 40P01)."
  echo
}

case "$scenario" in
  all)
    run_lock_wait
    run_lock_timeout
    run_deadlock
    ;;
  lock-wait)
    run_lock_wait
    ;;
  lock-timeout)
    run_lock_timeout
    ;;
  deadlock)
    run_deadlock
    ;;
esac

echo "Latest concurrency_log rows:"
db_psql "$LAB_DB_NAME" -c "
  SELECT log_id,
         log_timestamp,
         isolation_level,
         conflict_type,
         resource_info,
         wait_duration_ms,
         error_code
  FROM concurrency_log
  ORDER BY log_id DESC
  LIMIT 5;"

echo
echo "Summarize events with: $0 --report --minutes 60"
