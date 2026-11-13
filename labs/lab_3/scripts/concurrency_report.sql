-- concurrency_report.sql
-- Summaries over concurrency_log for a configurable timeframe.
--
-- Run through the harness:
--   ./log_concurrency.sh --report --minutes 60
--
-- The script may also be piped into psql directly. When :minutes is not set,
-- 60 is used:
--   psql -v minutes=1440 -f concurrency_report.sql

\if :{?minutes}
\else
    \set minutes 60
\endif

\echo
\echo '1) Events by conflict type and isolation level'
SELECT
    conflict_type,
    isolation_level,
    count(*) AS events,
    count(*) FILTER (WHERE wait_duration_ms IS NOT NULL) AS timed_events,
    round(avg(wait_duration_ms), 1) AS avg_wait_ms,
    round(max(wait_duration_ms), 1) AS max_wait_ms,
    min(log_timestamp) AS first_event,
    max(log_timestamp) AS last_event
FROM concurrency_log
WHERE log_timestamp >= now() - make_interval(mins => :minutes)
GROUP BY conflict_type, isolation_level
ORDER BY events DESC, conflict_type, isolation_level;

\echo
\echo '2) Totals by conflict type'
SELECT
    conflict_type,
    count(*) AS events,
    round(avg(wait_duration_ms), 1) AS avg_wait_ms,
    round(max(wait_duration_ms), 1) AS max_wait_ms,
    max(log_timestamp) AS last_event
FROM concurrency_log
WHERE log_timestamp >= now() - make_interval(mins => :minutes)
GROUP BY conflict_type
ORDER BY events DESC, conflict_type;

\echo
\echo '3) Lock hotspots by table'
SELECT
    coalesce(table_name, '(unknown)') AS table_name,
    conflict_type,
    count(*) AS events,
    round(avg(wait_duration_ms), 1) AS avg_wait_ms,
    round(max(wait_duration_ms), 1) AS max_wait_ms
FROM concurrency_log
WHERE log_timestamp >= now() - make_interval(mins => :minutes)
GROUP BY table_name, conflict_type
ORDER BY events DESC, table_name, conflict_type;

\echo
\echo '4) Recent events'
SELECT
    log_id,
    log_timestamp,
    isolation_level,
    conflict_type,
    resource_info,
    wait_duration_ms,
    error_code,
    scenario
FROM concurrency_log
WHERE log_timestamp >= now() - make_interval(mins => :minutes)
ORDER BY log_timestamp DESC, log_id DESC
LIMIT 20;
