CREATE TABLE IF NOT EXISTS replication_alerts (
  alert_id BIGSERIAL PRIMARY KEY,
  node_name TEXT NOT NULL,
  alert_time TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  anomaly_type TEXT NOT NULL,
  details TEXT
);
