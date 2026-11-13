# Lab 3 — Transactions and Concurrency

This lab uses the shared PostgreSQL instance and owns the `concurrency_db`
database. The exercises demonstrate transaction isolation, MVCC snapshots, and
deadlock detection.

## Usage

```bash
make up
make lab_3-setup
make lab_3
```

The equivalent direct command is:

```bash
./labs/lab_3/scripts/create_db_env.sh
```

The setup script is safe to run repeatedly. Set `LAB_DB_NAME` to use a
different database name:

```bash
LAB_DB_NAME=my_concurrency_db ./labs/lab_3/scripts/create_db_env.sh
```

| Script | Exercise |
|---|---|
| `scripts/isolation_levels.sh` | Compare `READ COMMITTED` and `REPEATABLE READ` |
| `scripts/mvcc_demo.sh` | Observe a repeatable-read snapshot |
| `scripts/simulate_deadlock.sh` | Run and log a deadlock (`--instructions` for manual steps) |
| `scripts/log_concurrency.sh` | Run lock, timeout and deadlock scenarios, or show the report |

## Activity #3: Concurrency analysis and logging tool

The lab can run concurrent transactions that block each other, detect the
conflict, and append an event to `concurrency_log`. The same table then supports
timeframe and isolation-level reports, which is how production monitoring turns
locking problems into evidence for tuning.

### Files

| File | Purpose |
|---|---|
| `scripts/init_db.sql` | Creates `account` and the `concurrency_log` table |
| `scripts/concurrency_logging.sql` | Defines `log_concurrency_event()` and the lock probes |
| `scripts/log_concurrency.sh` | Runs the scenarios or the report |
| `scripts/concurrency_report.sql` | Summary, hotspot and recent-event queries |
| `scripts/simulate_deadlock.sh` | Automated deadlock wrapper |

### Table

```sql
CREATE TABLE IF NOT EXISTS concurrency_log (
    log_id           BIGSERIAL PRIMARY KEY,
    log_timestamp    TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    isolation_level  TEXT NOT NULL,
    conflict_type    TEXT NOT NULL,
    resource_info    TEXT NOT NULL,
    table_name       TEXT,
    row_info         TEXT,
    wait_duration_ms NUMERIC(12, 3),
    error_code       TEXT,
    backend_pid      INT,
    blocking_pid     INT,
    scenario         TEXT,
    details          JSONB,
    logged_by        NAME NOT NULL DEFAULT current_user
);
```

- `log_timestamp` uses `clock_timestamp()` so events from one run get distinct
  timestamps.
- `resource_info` is the human-readable table/row description; `table_name` and
  `row_info` make grouping and filtering easier.
- `wait_duration_ms` is measured inside PostgreSQL, not in the shell, so Docker
  and psql startup time do not inflate the value.
- `error_code` stores the SQLSTATE: `55P03` for a lock timeout and `40P01` for a
  deadlock.
- `backend_pid` and `blocking_pid` answer "who waited, and who held the lock?".
- The table is append-only. Keeping every event is what makes the timeframe
  report and isolation-level comparison useful.

### Usage

```bash
make up
make lab_3-setup

# Run all three scenarios
./labs/lab_3/scripts/log_concurrency.sh

# Run one scenario
./labs/lab_3/scripts/log_concurrency.sh --scenario lock-wait
./labs/lab_3/scripts/log_concurrency.sh --scenario lock-timeout
./labs/lab_3/scripts/log_concurrency.sh --scenario deadlock

# Try a different isolation level
./labs/lab_3/scripts/log_concurrency.sh --scenario lock-wait \
  --isolation "REPEATABLE READ"

# Summarize the last 60 minutes
./labs/lab_3/scripts/log_concurrency.sh --report --minutes 60
```

With make:

```bash
make lab_3-log
make lab_3-log ARGS="--scenario deadlock"
make lab_3-report ARGS="--minutes 60"
```

### Scenarios

| Scenario | What happens | Detection |
|---|---|---|
| `lock-wait` | The holder locks a row for three seconds; the waiter locks the same row and waits | `clock_timestamp()` measures the wait; rows above 50 ms are logged as `lock_wait` |
| `lock-timeout` | The waiter uses `lock_timeout = 1s` while the holder keeps the row | The exception handler catches SQLSTATE `55P03` and logs `lock_timeout` |
| `deadlock` | Session A locks Alice then Bob; session B locks Bob then Alice | PostgreSQL aborts one transaction with SQLSTATE `40P01`; the harness logs `deadlock` with the victim and blocker PIDs |

The probes use `SELECT ... FOR UPDATE`, so they acquire real row locks without
changing account balances. They need the normal lab `SELECT` and `UPDATE`
privileges on `account`, but never modify its rows.

### How detection works

1. Each background session sets a unique `application_name`.
2. The harness polls `pg_stat_activity` until the holder is sleeping in
   `pg_sleep`; this confirms the first lock has been acquired before the waiter
   starts. The same query returns the holder's backend PID.
3. The waiter runs inside an explicit transaction:
   - `demo_lock_wait_probe()` measures the `SELECT ... FOR UPDATE` with
     `clock_timestamp()` and logs a `lock_wait` event.
   - `demo_lock_timeout_probe()` sets a transaction-local `lock_timeout` and
     catches `lock_not_available` (`55P03`) in a PL/pgSQL exception block, then
     logs `lock_timeout`.
4. For the deadlock scenario, both sessions sleep while holding their first
   row. Their second lock forms a cycle; `deadlock_timeout = '500ms'` makes
   PostgreSQL detect it quickly. The harness inspects the psql stderr, finds the
   victim, and inserts one `deadlock` row with `40P01`.

Deadlock victim selection is intentionally left to PostgreSQL. Either session
can be aborted; the harness records whichever one failed.

### Reporting

`concurrency_report.sql` accepts `:minutes` and produces four result sets:

1. events grouped by conflict type and isolation level;
2. totals by conflict type;
3. lock hotspots by table;
4. the most recent events.

The same summary can be run directly:

```sql
SELECT conflict_type,
       isolation_level,
       count(*) AS events,
       round(avg(wait_duration_ms), 1) AS avg_wait_ms,
       round(max(wait_duration_ms), 1) AS max_wait_ms
FROM concurrency_log
WHERE log_timestamp >= now() - interval '1 hour'
GROUP BY conflict_type, isolation_level
ORDER BY events DESC;
```

To watch live lock waits outside the lab harness:

```sql
SELECT pid,
       application_name,
       wait_event_type,
       wait_event,
       pg_blocking_pids(pid) AS blocking_pids,
       query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock';
```

### Timeframe and value

This activity fits in a few hours because it builds on the existing concurrency
scripts and the shared database layer. In production the same data helps:

- **Troubleshooting** — a support engineer can see when a transaction waited,
  on which row, and for how long instead of guessing from a user report.
- **Tuning** — repeated lock waits on one table point to missing indexes,
  overly broad transactions or a bad access order.
- **Isolation decisions** — grouping by `isolation_level` shows whether
  `REPEATABLE READ` or `SERIALIZABLE` is producing more conflicts than the
  application can tolerate.
- **Alerting and dashboards** — the report query can feed a Grafana panel or an
  alert when deadlocks exceed a threshold in a rolling window.
- **Retention** — `concurrency_log` grows forever, so a real deployment should
  add a retention job or partition the table by `log_timestamp`.

Useful PostgreSQL settings for production investigation are `log_lock_waits`,
`deadlock_timeout` and a statement-level `lock_timeout`. The lab sets
`deadlock_timeout` only for the demo sessions, so the server configuration is
left unchanged.

### Caveats

- The scenarios are synthetic and deliberately slow; they are not a benchmark.
- A single run logs a small number of events. Use repeated runs or a real
  monitor if you need a meaningful trend.
- `log_concurrency.sh` itself is not a background collector. It demonstrates
  the detection and logging pattern; a production agent would poll
  `pg_stat_activity`/`pg_locks` or consume server logs continuously.
- `concurrency_log` is append-only, like `performance_log` in lab 2.
