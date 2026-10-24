-- create_tables.sql
-- Creates the lab_2 tables: departments, employees and performance_log.
-- Safe to re-run: existing tables are left untouched.

CREATE TABLE IF NOT EXISTS departments (
    id        SERIAL PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL,
    location  VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS employees (
    id            SERIAL PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    department    VARCHAR(50) NOT NULL,
    department_id INT REFERENCES departments(id),
    email         VARCHAR(255)
);

-- One row per critical query per logging run. Append-only by design: keeping
-- every sample is what makes the historical trends useful.
CREATE TABLE IF NOT EXISTS performance_log (
    id             BIGSERIAL PRIMARY KEY,
    query_name     TEXT NOT NULL,
    query_text     TEXT NOT NULL,
    estimated_cost NUMERIC(14, 2),
    actual_time    NUMERIC(14, 3),
    logged_at      TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

COMMENT ON TABLE performance_log IS
    'EXPLAIN ANALYZE samples for the critical queries defined in performance_logging.sql';
COMMENT ON COLUMN performance_log.query_name IS
    'Stable label used to group samples of the same query across runs';
COMMENT ON COLUMN performance_log.estimated_cost IS
    'Top-level Total Cost reported by EXPLAIN (arbitrary cost units)';
COMMENT ON COLUMN performance_log.actual_time IS
    'Top-level Execution Time reported by EXPLAIN ANALYZE (milliseconds)';

CREATE INDEX IF NOT EXISTS idx_performance_log_query_time
    ON performance_log (query_name, logged_at DESC);
