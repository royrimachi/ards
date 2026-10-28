# Lab 2 — SQL Optimization

The lab's shared PostgreSQL instance lives at the repository root; this lab owns
the `optimization_db` database. `create_tables.sql` creates a small
`departments` table, a 20,000-row `employees` table, and the `performance_log`
table used by Activity #2.

## Activity #2: Automated query performance logger

The lab can periodically run a predefined list of critical queries with
`EXPLAIN ANALYZE`, parse the plan, and store one sample per query in
`performance_log`. Repeating the logger builds a history that can be compared
across runs, before/after index changes, or over days and weeks.

### Files

| File | Purpose |
|---|---|
| `scripts/create_tables.sql` | Adds `performance_log` to the lab schema |
| `scripts/performance_logging.sql` | Defines `log_query_performance()` and runs the five critical queries |
| `scripts/performance_report.sql` | Summary, run-over-run, daily-trend and first-vs-latest reports |
| `scripts/log_performance.sh` | Wrapper that runs the logger or the report |

### Table

```sql
CREATE TABLE IF NOT EXISTS performance_log (
    id             BIGSERIAL PRIMARY KEY,
    query_name     TEXT NOT NULL,
    query_text     TEXT NOT NULL,
    estimated_cost NUMERIC(14, 2),
    actual_time    NUMERIC(14, 3),
    logged_at      TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
```

- `query_name` is the stable label used by the reports.
- `query_text` stores the exact SQL that was executed.
- `estimated_cost` is the plan's top-level `Total Cost` in planner cost units.
- `actual_time` is the plan's top-level `Execution Time` in milliseconds.
- `logged_at` uses `clock_timestamp()` so rows from the same run get distinct
  timestamps.

The table is append-only: each run adds new samples. Keeping every sample is what
makes trend analysis possible; overwriting a previous row would destroy the
history.

### Usage

```bash
make up
make lab_2-schema
make lab_2-data

# One logging run
make lab_2-log

# Three runs, two seconds apart, to demonstrate variation
make lab_2-log ARGS="--repeat 3 --interval 2"

# Compare the samples
make lab_2-report
```

Without `make`:

```bash
./labs/lab_2/scripts/log_performance.sh
./labs/lab_2/scripts/log_performance.sh --repeat 3 --interval 2
./labs/lab_2/scripts/log_performance.sh --report
```

The report produces four result sets:

1. **Per-query summary** — number of runs, average estimated cost, average,
   minimum and maximum actual time, and the last sample timestamp.
2. **Run-over-run change** — `delta_ms` and `pct_change` against the previous
   sample of the same query.
3. **Daily trend** — average time and cost grouped by day, useful for long-term
   history.
4. **First vs latest** — a compact view of whether each query improved or
   regressed over the whole history.

Illustrative output from the per-query summary:

```text
       query_name       | runs | avg_estimated_cost | avg_actual_ms | ...
------------------------+------+--------------------+---------------+-----
 employees_by_department|    3 |             245.00 |         1.234 | ...
 employees_by_last_name |    3 |             245.00 |        12.345 | ...
```

### Before/after index experiment

Log a baseline, create the indexes from the existing lab exercise, log again,
then compare:

```bash
make lab_2-log
make lab_2-indexes
make lab_2-log
make lab_2-report
```

Run this experiment on a fresh lab: if you already ran `create_indexes.sh`, the
baseline will already include the indexes.

`employees_by_department` should benefit from
`idx_dept_lastname (department, last_name)`, and `employees_by_email` from
`idx_email_lower (lower(email))`. The report shows the actual-time drop while
`employees_by_last_name` remains a sequential scan because no index covers it.

### How the plan is parsed

`performance_logging.sql` requests `EXPLAIN (ANALYZE, FORMAT JSON)`. PostgreSQL
returns the plan as JSON, so the function can extract the metrics directly:

```sql
EXECUTE format('EXPLAIN (ANALYZE, FORMAT JSON) %s', p_query_text)
    INTO v_plan;

(v_plan -> 0 -> 'Plan' ->> 'Total Cost')::NUMERIC
(v_plan -> 0 ->> 'Execution Time')::NUMERIC
```

This avoids shell string parsing, `jq`, or a Python dependency. The query list is
a `VALUES` list in the same file; add new named queries there.

### Scheduling with cron

For continuous collection, run the logger from cron. Use absolute paths in cron:

```cron
*/15 * * * * cd /path/to/ards && ./labs/lab_2/scripts/log_performance.sh >> /tmp/ards-performance.log 2>&1
```

Each execution appends five new rows, so a 15-minute schedule produces 480 rows
per day before any retention policy is applied.

### Why enterprises keep this history

- **Proactive tuning and alerting** — a rolling baseline exposes a query that
  suddenly becomes 30% slower, often before users report it. The same data can
  feed alerts or a dashboard.
- **Index decisions** — comparing samples before and after an index change shows
  whether the index actually helped, instead of relying on the planner's estimate
  alone. It also highlights expensive queries that still need an index.
- **Capacity planning** — latency and run-frequency history show how the workload
  grows with data volume and traffic. That supports CPU, memory and I/O forecasts
  and helps schedule maintenance in low-traffic windows.
- **Release validation** — pre/post-deployment samples catch planner regressions
  caused by statistics, configuration or PostgreSQL version changes.
- **Maintenance scheduling** — a gradual slowdown can indicate stale statistics,
  bloat or missing indexes; the history provides evidence for `ANALYZE`,
  `VACUUM`, `REINDEX` or partitioning work.

### Caveats

- `EXPLAIN ANALYZE` **executes** the statement. Keep the list read-only and never
  add `INSERT`, `UPDATE` or `DELETE` statements to it.
- Logging adds load. Collect a small set of critical queries, off-peak or on a
  replica when possible, rather than every query in the application.
- A single timing is noisy. Use several runs and compare averages or trends
  rather than one sample.
- `performance_log` grows forever. For a real deployment, add a retention job or
  [partition the table by `logged_at`](#optional-partitioning-advanced).

## Optional: partitioning (advanced)

`make lab_2-partition` creates `employees_partitioned`, a list-partitioned copy of
`employees` keyed on `department`, inserts sample rows and shows where they land.
Add `ARGS=--bulk` to also copy the existing `employees` rows:

```bash
make lab_2-partition
make lab_2-partition ARGS=--bulk
```

### Insert into the parent, never the partitions

With declarative partitioning you write to the parent table and PostgreSQL routes
each row to the partition whose bounds match:

```sql
INSERT INTO employees_partitioned (first_name, last_name, department, email)
VALUES ('Ana', 'Ruiz', 'Sales', 'ana.ruiz@example.com');
```

The row physically lives in `employees_sales`, but `SELECT * FROM
employees_partitioned` returns it like any other row. Do not `INSERT INTO
employees_sales` directly: bypassing the parent hides the routing behaviour and
breaks when partition bounds change.

A department with **no matching partition** fails the whole statement:

```text
ERROR: no partition of relation "employees_partitioned" found for row
DETAIL: Partition key of the failing row contains (department) = (Engineering).
```

That is why the demo creates one partition per value used by `insert_data.sql`.
The alternative is a catch-all:

```sql
CREATE TABLE employees_default
    PARTITION OF employees_partitioned DEFAULT;
```

A `DEFAULT` partition absorbs unknown values, but its rows are invisible to
partition pruning and they **block** a later `CREATE TABLE ... PARTITION OF ...
FOR VALUES IN (...)` that covers them until the rows are moved out.

### Bulk load

`INSERT ... SELECT` and `COPY` also target the parent, so every row is routed in
one pass instead of 20,000 round trips:

```sql
INSERT INTO employees_partitioned (first_name, last_name, department, department_id, email)
SELECT first_name, last_name, department, department_id, email
FROM employees;
```

The demo guards this with an anti-join on the business columns, so re-running
`make lab_2-partition ARGS=--bulk` does not duplicate rows.

### Verifying the routing

`tableoid` names the physical partition that holds each row:

```sql
SELECT tableoid::regclass AS partition, count(*) AS rows
FROM employees_partitioned
GROUP BY 1
ORDER BY 1;
```

`\d+ employees_partitioned` lists the partitions and their bounds. Filtering the
parent on the partition key also prunes the plan down to the relevant partition,
which the demo shows with `EXPLAIN (COSTS OFF)`.

### Two constraints to keep in mind

- **The primary key must include the partition key.** The demo uses
  `PRIMARY KEY (id, department)`, so `id` is unique per department, not globally.
  Two departments can both hold `id = 1`; use a shared sequence or a composite
  business key if you need uniqueness across the whole table.
- **Attaching an existing table** needs matching data:
  `ALTER TABLE employees_partitioned ATTACH PARTITION employees_sales FOR VALUES
  IN ('Sales');` scans and validates the table, and takes an `ACCESS EXCLUSIVE`
  lock unless a matching `CHECK` constraint was added first.
