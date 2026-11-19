# Lab 4 — PostgreSQL Streaming Replication

This lab runs an isolated PostgreSQL 14 primary and standby pair. The services
are defined in the root Compose file and use their own named volumes and
network, so they do not change the shared PostgreSQL service used by labs 1–3.

## Usage

```bash
make lab_4-setup
make lab_4-init
make lab_4-test
make lab_4-health ARGS=--once
make lab_4-failover
```

The interactive menu is available with `make lab_4`. The primary and standby
are exposed on ports `55432` and `55433` by default. Override them with
`LAB4_MASTER_PORT` and `LAB4_SLAVE_PORT`.

| Script | Exercise |
|---|---|
| `scripts/setup_docker_env.sh` | Pull images and start the primary |
| `scripts/init_replication.sh` | Configure the primary and clone the standby |
| `scripts/test_replication.sh` | Insert on the primary and verify on the standby |
| `scripts/check_replication_health.sh` | Poll replication state, lag, reachability, and record alerts |
| `scripts/simulate_failover.sh` | Stop the primary and promote the standby |

## Activity #4: Replication health checker and alerting

The health checker queries `pg_stat_replication` on the primary and
`pg_stat_wal_receiver` on the standby. It warns about unavailable services,
replication state changes, stale communication, or lag above the configured
threshold. Issues are inserted into the `replication_alerts` table when the
primary is reachable.

Run one check:

```bash
make lab_4-health ARGS=--once
```

Run continuously, polling every five seconds with a ten-second threshold:

```bash
make lab_4-health ARGS="--interval 5 --threshold 10"
```

The defaults are controlled by `LAB4_HEALTH_INTERVAL_SECONDS` and
`LAB4_HEALTH_THRESHOLD_SECONDS`. The checker can also be run from the
interactive menu.

View recorded alerts on the primary:

```bash
docker compose --project-name ards-lab4 exec master \
  psql -U postgres -d replication_db \
  -c "SELECT node_name, alert_time, anomaly_type, details
      FROM replication_alerts ORDER BY alert_time DESC;"
```

Initialization recreates the standby's named volume contents from a fresh
`pg_basebackup`; run it again whenever a clean replication exercise is needed.
