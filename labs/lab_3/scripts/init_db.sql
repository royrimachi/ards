-- Keep repeated setup quiet when tables and indexes already exist.
SET client_min_messages = warning;

CREATE TABLE IF NOT EXISTS account (
  id SERIAL PRIMARY KEY,
  owner_name VARCHAR(100) NOT NULL,
  balance NUMERIC(10, 2) NOT NULL
);

INSERT INTO account (owner_name, balance)
SELECT owner_name, balance
FROM (VALUES
  ('Alice', 1000.00::NUMERIC(10, 2)),
  ('Bob', 800.00::NUMERIC(10, 2))
) AS initial_data(owner_name, balance)
WHERE NOT EXISTS (
  SELECT 1
  FROM account
  WHERE account.owner_name = initial_data.owner_name
);

-- Append-only log of concurrency conflicts observed by the lab harness.
-- Keeping every event makes timeframe reports and isolation-level comparisons
-- possible, the same way performance_log keeps every EXPLAIN ANALYZE sample.
CREATE TABLE IF NOT EXISTS concurrency_log (
  log_id           BIGSERIAL PRIMARY KEY,
  log_timestamp    TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  isolation_level  TEXT NOT NULL,
  conflict_type    TEXT NOT NULL
                   CHECK (conflict_type IN (
                     'lock_wait',
                     'lock_timeout',
                     'deadlock',
                     'serialization_failure'
                   )),
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

COMMENT ON TABLE concurrency_log IS
  'Concurrency conflicts (lock waits, timeouts and deadlocks) captured by the lab harness';
COMMENT ON COLUMN concurrency_log.log_timestamp IS
  'When the conflict was recorded, using clock_timestamp() for sub-statement precision';
COMMENT ON COLUMN concurrency_log.isolation_level IS
  'Transaction isolation level of the affected transaction';
COMMENT ON COLUMN concurrency_log.conflict_type IS
  'lock_wait, lock_timeout, deadlock or serialization_failure';
COMMENT ON COLUMN concurrency_log.resource_info IS
  'Human-readable description of the locked table and row';
COMMENT ON COLUMN concurrency_log.wait_duration_ms IS
  'Measured wait in milliseconds, when available';
COMMENT ON COLUMN concurrency_log.error_code IS
  'PostgreSQL SQLSTATE observed for the conflict (for example 55P03 or 40P01)';
COMMENT ON COLUMN concurrency_log.scenario IS
  'Lab scenario that produced the event (lock_wait, lock_timeout or deadlock)';

CREATE INDEX IF NOT EXISTS idx_concurrency_log_time
  ON concurrency_log (log_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_concurrency_log_type_time
  ON concurrency_log (conflict_type, isolation_level, log_timestamp DESC);
