# Lab 4 — PostgreSQL Streaming Replication

This lab runs an isolated PostgreSQL 14 primary and standby pair. The services
are defined in the root Compose file and use their own named volumes and
network, so they do not change the shared PostgreSQL service used by labs 1–3.

## Usage

```bash
make lab_4-setup
make lab_4-init
make lab_4-test
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
| `scripts/simulate_failover.sh` | Stop the primary and promote the standby |

Initialization recreates the standby's named volume contents from a fresh
`pg_basebackup`; run it again whenever a clean replication exercise is needed.
