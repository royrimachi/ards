# ARDS Labs

Hands-on database labs. Every lab shares a single PostgreSQL instance managed
by Docker Compose at the repository root; each lab owns one database inside it.

```
ards/
├── compose.yaml                 # shared PostgreSQL service
├── .env                         # local credentials/ports (git-ignored)
├── .env.example                 # documented template
├── .idea/dataSources.xml        # shared DataGrip connections (no credentials)
├── Makefile                     # optional command facade (see below)
├── docker/postgres/initdb/      # creates one DB per lab on a fresh cluster
├── data/                        # runtime data (git-ignored, folder is kept)
│   └── postgres/                # PostgreSQL cluster (created on first start)
├── scripts/
│   ├── lib/db.sh                # shared access layer (compose + psql helpers)
│   ├── db-up.sh                 # start instance + ensure databases
│   ├── db-stop.sh               # stop instance, keep data
│   ├── db-status.sh             # status + database list
│   ├── db-create.sh             # create a database
│   └── db-shell.sh              # interactive psql
└── labs/
    └── lab_2/
        ├── README.md            # lab guide, incl. activity #2 performance logging
        ├── config.sh            # LAB_DB_NAME=optimization_db
        └── scripts/             # lab exercises
```

## Requirements

- Docker with the Compose v2+ plugin (`docker compose version`).
- Nothing else: PostgreSQL runs in the container.

## Quick start

```bash
cp .env.example .env        # first time only
make up                     # start PostgreSQL, create optimization_db
make lab_2                  # lab 2 interactive menu
```

Or run the lab steps directly with make:

```bash
make lab_2-schema           # create tables
make lab_2-data             # load 20,000 sample employees
make lab_2-explain
make lab_2-indexes
make lab_2-rewrite
make lab_2-partition
make lab_2-log ARGS="--repeat 3 --interval 2"
make lab_2-report
```

`make` is a convenience layer only; the scripts below work without it. Run
`make help` to list every target and `make labs` to list discovered labs.

The per-lab walkthrough and the query performance logging exercise are documented
in [labs/lab_2/README.md](labs/lab_2/README.md).

Connect with any SQL client at `127.0.0.1:5432` using the credentials from
`.env`, database `optimization_db`.

## Make targets

| Target | Effect |
|---|---|
| `make up` / `make stop` / `make restart` | Container lifecycle |
| `make status` | Container status, data directory and databases |
| `make down` | Remove the container (data stays in `data/postgres`) |
| `make psql DB=optimization_db` | Interactive psql |
| `make db-create DB=lab_3_db` | Create a database |
| `make db-info` | Print host, port, user and JDBC URLs for DataGrip |
| `make labs` | List discovered labs |
| `make lab_2` | Open a lab's interactive menu |
| `make lab_2-schema [ARGS=--reset]` | Create tables, or recreate only that lab's database |
| `make lab_2-data [ARGS=--force]` | Insert sample data |
| `make lab_2-explain` / `lab_2-indexes` / `lab_2-rewrite` / `lab_2-partition [ARGS=--bulk]` | Lab demos |
| `make lab_2-log [ARGS="--repeat 3 --interval 2"]` | Log EXPLAIN ANALYZE metrics for the critical queries |
| `make lab_2-report` | Show average timings, run-over-run deltas and daily trends |
| `make lab_2-reset` | **Destructive**: drop and recreate only that lab's database |
| `make check` | Validate shell syntax and the compose file |

Lab targets are pattern rules (`lab_%-schema`, `lab_%-data`, …), so `lab_3`,
`lab_4`, etc. work as soon as `labs/lab_N/config.sh` exists and its scripts
follow the naming convention. No Makefile change is required.

## Connecting with DataGrip

The repository commits `.idea/dataSources.xml`, which contains a shared,
password-free data source for `optimization_db`. Open the repository folder as a
DataGrip project and the source is loaded automatically.

1. Open **Data Sources and Drivers** (`Cmd+;` / `Ctrl+Alt+Shift+S`).
2. Select **ARDS optimization_db**.
3. Set **User** to `POSTGRES_USER` from `.env` (default `postgres`).
4. Set **Password** to `POSTGRES_PASSWORD` from `.env`.
5. Click **Test Connection**.

`make db-info` prints the host, port, user and JDBC URLs for every database.
DataGrip stores the password in the macOS Keychain (or KeePass); it is never
written to the repository.

Only connection definitions are versioned. `.idea/dataSources.local.xml` (which
holds your user name and introspection scope), `.idea/workspace.xml` and any
password are per-user and ignored by git. Do not create a URL-only data source
with credentials embedded in the JDBC URL — that would copy the password into
`dataSources.xml`.

For a new lab, duplicate the data source in DataGrip and change the database
name to `lab_N_db`, or add a `<data-source>` entry to `.idea/dataSources.xml`
with a new UUID. Then commit the updated file.

## Lifecycle

| Command | Effect |
|---|---|
| `scripts/db-up.sh` | Start the container and ensure configured databases exist |
| `scripts/db-status.sh` | Show container status, data directory and databases |
| `scripts/db-stop.sh` | Stop the container, preserve data |
| `docker compose down` | Remove the container; data stays in `data/postgres` |
| `docker compose down -v` | Removes named volumes only; bind-mounted data is untouched |

Lab scripts:

| Script | Effect |
|---|---|
| `start_container.sh` | Start the shared container, create `optimization_db` |
| `stop_container.sh` | Stop the container, preserve data |
| `create_schema.sh` | Create missing tables (re-runnable) |
| `create_schema.sh --reset` | Drop/recreate **only** `optimization_db` |
| `insert_data.sh` | Insert sample data; skips if employees already exist |
| `insert_data.sh --force` | Append another 20,000 employees |
| `log_performance.sh` | Run EXPLAIN ANALYZE over the critical queries and log metrics |
| `log_performance.sh --report` | Summarize `performance_log` over multiple runs |

## Adding a new lab

1. Create `labs/lab_N/config.sh` and declare its database:

   ```bash
   LAB_DB_NAME="${LAB_DB_NAME:-lab_n_db}"
   ```

2. In each script, source the shared layer and the lab config:

   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
   source "$SCRIPT_DIR/../config.sh"
   ```

3. Use the helpers only:

   ```bash
   db_require_running
   db_create "$LAB_DB_NAME"
   db_run_sql_file "$LAB_DB_NAME" "$SCRIPT_DIR/my_script.sql"
   db_psql "$LAB_DB_NAME" -c "SELECT ..."
   ```

4. Add the database name to `POSTGRES_DATABASES` in `.env` so `db-up.sh` creates
   it automatically, or run `scripts/db-create.sh lab_n_db` once.

5. Nothing to add to the root `Makefile`: it discovers labs from
   `labs/*/config.sh` and maps `lab_N-schema`, `lab_N-data`, etc. to the
   conventional script names (`create_schema.sh`, `insert_data.sh`,
   `explain_demo.sh`, `create_indexes.sh`, `query_rewrite.sh`,
   `partitioning_demo.sh`, `global_menu.sh`). Run `make labs` to confirm the new
   lab is discovered. Only add an explicit target (or a lab-local Makefile
   included by the root one) for custom actions outside that convention.

Rules:

- Never call `docker run`, `docker exec`, or `docker compose` directly in a lab.
- Never hardcode a container name; target the `postgres` service through `db.sh`.
- Never use the maintenance database (`postgres`) as a lab database.
- Destructive helpers must stay scoped to the lab's own database (`db_drop`
  refuses `postgres`, `template0` and `template1`).
- Keep the `Makefile` free of logic: every recipe calls an existing script.

## How the pieces fit

- `compose.yaml` defines one `postgres:14` service, a health check, a localhost
  port binding and a bind mount that stores the cluster in `data/postgres`.
- `docker/postgres/initdb/00-create-databases.sh` creates every database in
  `POSTGRES_DATABASES`. It only runs when the cluster is initialized.
- `scripts/lib/db.sh` loads `.env`, wraps `docker compose`, waits for
  `pg_isready`, and exposes `db_*` helpers used by every script.
- Lab scripts pass their own database name, so additional labs and scripts can
  coexist in the same container without collisions.

## Data and backups

The cluster is bind-mounted from `data/postgres` (configurable through
`POSTGRES_DATA_DIR` in `.env`), so it can be inspected and copied like any other
folder. The cluster directory is git-ignored; the parent folder is kept with
`data/.gitkeep`. PostgreSQL requires the data directory to be empty when the
cluster is initialized.

To take a consistent copy, stop the database first:

```bash
mkdir -p backups
./scripts/db-stop.sh
cp -a data/postgres "backups/postgres-$(date +%Y%m%d-%H%M%S)"
./scripts/db-up.sh
```

For an online backup, dump the logical databases instead:

```bash
docker compose exec -T postgres pg_dump -U postgres -Fc optimization_db \
  > optimization_db.dump
```

Restore with:

```bash
docker compose exec -T postgres pg_restore -U postgres -d optimization_db \
  < optimization_db.dump
```

On Linux, container files are written with uid `999`; on macOS, Docker Desktop
maps them to your user. Bind mounts are also slower than named volumes, which is
acceptable for these labs.

## Troubleshooting

**`POSTGRES_PASSWORD` missing** — copy the template: `cp .env.example .env`.

**Port 5432 already in use** — change `POSTGRES_PORT` in `.env` (for example
`5433`) and use `scripts/db-status.sh` to see the new mapping.

**A database added to `.env` does not appear** — init scripts only run on a new
cluster. Run `scripts/db-up.sh` (it ensures the configured databases) or
`scripts/db-create.sh <database>`.

**Old `postgres_optimization_lab` container** — it was started with
`docker run` and had no volume, so its data was ephemeral. Remove it once:

```bash
docker rm -f postgres_optimization_lab
./scripts/db-up.sh
./labs/lab_2/scripts/create_schema.sh
./labs/lab_2/scripts/insert_data.sh
```

**Start from scratch** — stop the container and delete the cluster files:

```bash
./scripts/db-stop.sh
rm -rf data/postgres/*
./scripts/db-up.sh
```

This wipes every lab, so prefer `create_schema.sh --reset` for a single lab.

**PostgreSQL fails to start with a permission error on macOS** — the bind mount
cannot apply the ownership the `postgres` entrypoint expects. Switch
`POSTGRES_DATA_DIR` to a path on a Docker-managed volume, or replace the bind
mount in `compose.yaml` with a local-driver volume:

```yaml
volumes:
  pgdata:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${PWD}/data/postgres
```
