# Lab 1 — DBMS Internals

This lab uses the shared MySQL 8.0 and PostgreSQL 14 services. Each service
owns a `demo_db` database with the same department, project, employee, and
employee-project schema, sample data, and metadata exercises.

## Usage

```bash
./labs/lab_1/scripts/start_container.sh
make lab_1-schema lab_1-data lab_1-metadata

./scripts/db-up.sh
make lab_1-postgres-schema lab_1-postgres-data lab_1-postgres-metadata
```

The interactive menu is also available with:

```bash
make lab_1
```

The regular `lab_1-*` targets use MySQL; the `lab_1-postgres-*` targets use
PostgreSQL. Set `LAB_DB_NAME` to use a different database name. Set connection
settings in `.env`.
