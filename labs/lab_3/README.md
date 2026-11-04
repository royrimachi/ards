# Lab 3 — Transactions and Concurrency

This lab uses the shared PostgreSQL instance and owns the `concurrency_db`
database. The exercises demonstrate transaction isolation, MVCC snapshots, and
deadlock detection.

## Usage

```bash
make up
./labs/lab_3/scripts/create_db_env.sh
make lab_3
```

The setup script is safe to run repeatedly. Set `LAB_DB_NAME` to use a
different database name:

```bash
LAB_DB_NAME=my_concurrency_db ./labs/lab_3/scripts/create_db_env.sh
```

| Script | Exercise |
|---|---|
| `scripts/isolation_levels.sh` | Compare `READ COMMITTED` and `REPEATABLE READ` |
| `scripts/mvcc_demo.sh` | Observe a repeatable-read snapshot |
| `scripts/simulate_deadlock.sh` | Trigger PostgreSQL deadlock detection |
