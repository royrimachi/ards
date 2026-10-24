-- performance_logging.sql
-- Runs the predefined critical queries with EXPLAIN ANALYZE and appends their
-- metrics to performance_log.
--
-- The plan is requested as JSON, so parsing happens inside PostgreSQL and no
-- external tool (jq, Python, awk) is needed.
--
-- Re-runnable: every run inserts a new sample for each query. Use
-- performance_report.sql to compare samples over time.
--
-- Only read-only statements belong in the list below: EXPLAIN ANALYZE actually
-- executes the statement, not just the planner.

CREATE OR REPLACE FUNCTION log_query_performance(
    p_query_name TEXT,
    p_query_text TEXT
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_plan JSON;
BEGIN
    EXECUTE format('EXPLAIN (ANALYZE, FORMAT JSON) %s', p_query_text)
        INTO v_plan;

    INSERT INTO performance_log (
        query_name,
        query_text,
        estimated_cost,
        actual_time
    )
    VALUES (
        p_query_name,
        p_query_text,
        (v_plan -> 0 -> 'Plan' ->> 'Total Cost')::NUMERIC,
        (v_plan -> 0 ->> 'Execution Time')::NUMERIC
    );
END;
$$;

DO $$
DECLARE
    q RECORD;
BEGIN
    IF to_regclass('public.performance_log') IS NULL THEN
        RAISE EXCEPTION
            'performance_log does not exist; run create_schema.sh first';
    END IF;

    FOR q IN
        SELECT *
        FROM (VALUES
            (
                'employees_by_department',
                $sql$SELECT * FROM employees WHERE department = 'Sales' AND last_name = 'Smith'$sql$
            ),
            (
                'employees_by_last_name',
                $sql$SELECT * FROM employees WHERE last_name = 'Smith'$sql$
            ),
            (
                'employees_by_email',
                $sql$SELECT * FROM employees WHERE lower(email) = 'john.smith@example.com'$sql$
            ),
            (
                'employees_join_location',
                $sql$SELECT e.first_name, e.last_name, d.dept_name FROM employees e JOIN departments d ON e.department_id = d.id WHERE d.location = 'New York'$sql$
            ),
            (
                'headcount_by_department',
                $sql$SELECT department, count(*) AS headcount FROM employees GROUP BY department ORDER BY headcount DESC$sql$
            )
        ) AS v(query_name, query_text)
    LOOP
        PERFORM log_query_performance(q.query_name, q.query_text);
    END LOOP;
END;
$$;
