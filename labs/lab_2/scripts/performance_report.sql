-- performance_report.sql
-- Summaries over performance_log. Run with:
--   ./log_performance.sh --report
--
-- The four result sets show the same history from different angles:
-- per-query averages, run-over-run changes, daily trends, and first-vs-latest.

-- 1) Average metrics for each critical query.
SELECT
    query_name,
    count(*) AS runs,
    round(avg(estimated_cost), 2) AS avg_estimated_cost,
    round(avg(actual_time), 3) AS avg_actual_ms,
    round(min(actual_time), 3) AS min_actual_ms,
    round(max(actual_time), 3) AS max_actual_ms,
    max(logged_at) AS last_logged_at
FROM performance_log
GROUP BY query_name
ORDER BY avg_actual_ms DESC;

-- 2) Change from one run to the next, with the percentage difference.
WITH runs AS (
    SELECT
        id,
        query_name,
        logged_at,
        actual_time,
        lag(actual_time) OVER (
            PARTITION BY query_name
            ORDER BY logged_at, id
        ) AS previous_actual_time
    FROM performance_log
)
SELECT
    query_name,
    logged_at,
    actual_time AS actual_ms,
    round(actual_time - previous_actual_time, 3) AS delta_ms,
    round(
        100.0 * (actual_time - previous_actual_time)
        / NULLIF(previous_actual_time, 0),
        1
    ) AS pct_change
FROM runs
ORDER BY query_name, logged_at, id;

-- 3) Daily trend: useful once the logger has been running for several days.
SELECT
    date_trunc('day', logged_at)::date AS day,
    query_name,
    count(*) AS runs,
    round(avg(actual_time), 3) AS avg_actual_ms,
    round(avg(estimated_cost), 2) AS avg_estimated_cost
FROM performance_log
GROUP BY date_trunc('day', logged_at), query_name
ORDER BY day, avg_actual_ms DESC;

-- 4) First run vs latest run: a quick way to spot improvement or regression.
WITH ranked AS (
    SELECT
        query_name,
        actual_time,
        row_number() OVER (
            PARTITION BY query_name
            ORDER BY logged_at, id
        ) AS run_number,
        count(*) OVER (PARTITION BY query_name) AS total_runs
    FROM performance_log
)
SELECT
    query_name,
    round(avg(actual_time) FILTER (WHERE run_number = 1), 3) AS first_run_ms,
    round(avg(actual_time) FILTER (WHERE run_number = total_runs), 3) AS latest_run_ms,
    round(
        avg(actual_time) FILTER (WHERE run_number = total_runs)
        - avg(actual_time) FILTER (WHERE run_number = 1),
        3
    ) AS delta_ms
FROM ranked
GROUP BY query_name
ORDER BY delta_ms DESC NULLS LAST;
