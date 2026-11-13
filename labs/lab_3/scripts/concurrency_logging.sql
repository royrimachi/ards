-- concurrency_logging.sql
-- Logging helpers for the transactions and concurrency lab.
--
-- log_concurrency_event() is the single insert path used by the probes and by
-- the bash harness. The probe functions below run the actual locking
-- statements so the wait measurement happens inside PostgreSQL, not in the
-- shell or Docker client.

-- Keep CREATE OR REPLACE quiet when the functions already exist.
SET client_min_messages = warning;

-- Append one concurrency event and return its log_id.
CREATE OR REPLACE FUNCTION log_concurrency_event(
    p_conflict_type TEXT,
    p_isolation_level TEXT,
    p_resource_info TEXT,
    p_table_name TEXT DEFAULT NULL,
    p_row_info TEXT DEFAULT NULL,
    p_wait_duration_ms NUMERIC DEFAULT NULL,
    p_error_code TEXT DEFAULT NULL,
    p_backend_pid INT DEFAULT NULL,
    p_blocking_pid INT DEFAULT NULL,
    p_details JSONB DEFAULT NULL,
    p_scenario TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_log_id BIGINT;
BEGIN
    INSERT INTO concurrency_log (
        isolation_level,
        conflict_type,
        resource_info,
        table_name,
        row_info,
        wait_duration_ms,
        error_code,
        backend_pid,
        blocking_pid,
        scenario,
        details
    )
    VALUES (
        upper(p_isolation_level),
        lower(p_conflict_type),
        p_resource_info,
        p_table_name,
        p_row_info,
        p_wait_duration_ms,
        p_error_code,
        p_backend_pid,
        p_blocking_pid,
        p_scenario,
        p_details
    )
    RETURNING log_id INTO v_log_id;

    RETURN v_log_id;
END;
$$;

COMMENT ON FUNCTION log_concurrency_event(
    TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, TEXT, INT, INT, JSONB, TEXT
) IS
    'Inserts one concurrency_log row and returns its log_id';

-- Try to lock an account row and log the wait when it is meaningful.
--
-- The function is called inside an explicit transaction. SELECT ... FOR UPDATE
-- blocks until the holder releases the row, while clock_timestamp() measures
-- only the statement that waited. The account balance is never modified.
CREATE OR REPLACE FUNCTION demo_lock_wait_probe(
    p_owner_name TEXT,
    p_blocker_pid INT DEFAULT NULL,
    p_holder_app TEXT DEFAULT NULL,
    p_min_wait_ms NUMERIC DEFAULT 50
)
RETURNS TABLE (event_log_id BIGINT, observed_wait_ms NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_started_at TIMESTAMPTZ := clock_timestamp();
    v_wait_ms NUMERIC;
    v_account_id INT;
    v_log_id BIGINT;
BEGIN
    SELECT id INTO v_account_id
    FROM account
    WHERE owner_name = p_owner_name
    FOR UPDATE;

    v_wait_ms := round(
        extract(epoch FROM clock_timestamp() - v_started_at) * 1000,
        3
    );

    IF v_account_id IS NULL THEN
        RAISE EXCEPTION 'account row for owner % does not exist', p_owner_name;
    END IF;

    IF v_wait_ms >= p_min_wait_ms THEN
        v_log_id := log_concurrency_event(
            p_conflict_type => 'lock_wait',
            p_isolation_level => current_setting('transaction_isolation'),
            p_resource_info => format('account: row owner_name=%s', p_owner_name),
            p_table_name => 'account',
            p_row_info => format('owner_name=%s', p_owner_name),
            p_wait_duration_ms => v_wait_ms,
            p_backend_pid => pg_backend_pid(),
            p_blocking_pid => p_blocker_pid,
            p_details => jsonb_build_object(
                'holder_application_name', p_holder_app
            ),
            p_scenario => 'lock_wait'
        );
    END IF;

    RETURN QUERY SELECT v_log_id, v_wait_ms;
END;
$$;

-- Try to lock an account row with a transaction-local lock_timeout and log the
-- failure when PostgreSQL raises SQLSTATE 55P03 (lock_not_available).
--
-- The exception block rolls back only the failed statement, so the log insert
-- still commits with the caller's transaction.
CREATE OR REPLACE FUNCTION demo_lock_timeout_probe(
    p_owner_name TEXT,
    p_lock_timeout_ms INT DEFAULT 1000,
    p_blocker_pid INT DEFAULT NULL,
    p_holder_app TEXT DEFAULT NULL
)
RETURNS TABLE (event_log_id BIGINT, observed_wait_ms NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_started_at TIMESTAMPTZ := clock_timestamp();
    v_wait_ms NUMERIC;
    v_account_id INT;
    v_log_id BIGINT;
BEGIN
    -- true = transaction-local setting; it is reverted when the caller commits.
    PERFORM set_config(
        'lock_timeout',
        p_lock_timeout_ms::TEXT || 'ms',
        true
    );

    BEGIN
        SELECT id INTO v_account_id
        FROM account
        WHERE owner_name = p_owner_name
        FOR UPDATE;

        v_wait_ms := round(
            extract(epoch FROM clock_timestamp() - v_started_at) * 1000,
            3
        );

        IF v_account_id IS NULL THEN
            RAISE EXCEPTION 'account row for owner % does not exist', p_owner_name;
        END IF;

        -- The lock was granted before the timeout; nothing to log.
        RETURN QUERY SELECT NULL::BIGINT, v_wait_ms;
        RETURN;
    EXCEPTION WHEN lock_not_available THEN
        v_wait_ms := round(
            extract(epoch FROM clock_timestamp() - v_started_at) * 1000,
            3
        );

        v_log_id := log_concurrency_event(
            p_conflict_type => 'lock_timeout',
            p_isolation_level => current_setting('transaction_isolation'),
            p_resource_info => format('account: row owner_name=%s', p_owner_name),
            p_table_name => 'account',
            p_row_info => format('owner_name=%s', p_owner_name),
            p_wait_duration_ms => v_wait_ms,
            p_error_code => SQLSTATE,
            p_backend_pid => pg_backend_pid(),
            p_blocking_pid => p_blocker_pid,
            p_details => jsonb_build_object(
                'lock_timeout_ms', p_lock_timeout_ms,
                'holder_application_name', p_holder_app
            ),
            p_scenario => 'lock_timeout'
        );

        RETURN QUERY SELECT v_log_id, v_wait_ms;
        RETURN;
    END;
END;
$$;
