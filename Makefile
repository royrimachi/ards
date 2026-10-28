# Makefile
# Thin command facade for the project. All behavior stays in the shell scripts;
# using make is optional.
#
# Lab targets are pattern rules: `make lab_2-schema` maps to
# labs/lab_2/scripts/create_schema.sh. Adding a new lab does not require any
# change here, as long as its scripts follow the naming convention.

.DEFAULT_GOAL := help
SHELL := bash

# Default database for `make psql` (override with DB=...).
DB ?= optimization_db
# Extra flags for targets that accept them (e.g. ARGS=--force).
ARGS ?=

# Labs discovered from labs/*/config.sh (e.g. lab_2).
LABS := $(notdir $(patsubst %/config.sh,%,$(wildcard labs/*/config.sh)))

# guard <stem>: fails with a helpful message when the lab does not exist.
guard = @test -d "labs/lab_$1" || { echo "error: unknown lab '$1' (available: $(LABS))" >&2; exit 1; }

.PHONY: help up stop restart status down psql db-create db-info labs check $(LABS)

help: ## Show this help
	@echo "ARDS Labs - available targets"
	@echo
	@grep -E '^[a-zA-Z0-9_.%-]+:.*## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo
	@echo "Labs: $(LABS)"
	@echo "Examples: make lab_2 | make lab_2-schema | make lab_2-data ARGS=--force"

up: ## Start shared PostgreSQL and ensure configured databases
	./scripts/db-up.sh

stop: ## Stop the container, preserving data
	./scripts/db-stop.sh

restart: stop up ## Restart the container (data is preserved)

status: ## Show container status, data directory and databases
	./scripts/db-status.sh

down: ## Remove the container (data stays in ./data/postgres)
	docker compose down

psql: ## Open psql: make psql [DB=database]
	./scripts/db-shell.sh $(DB)

db-create: ## Create a database: make db-create DB=lab_3_db
	./scripts/db-create.sh $(DB)

db-info: ## Print connection details and JDBC URLs for DataGrip
	./scripts/db-info.sh

labs: ## List discovered labs
	@echo "$(LABS)"

# Lab targets ---------------------------------------------------------------
# Menus are generated for each discovered lab, so `make lab_2` exists without
# overlapping the `lab_%-action` pattern rules.

$(LABS): %: labs/%/scripts/global_menu.sh
	./labs/$*/scripts/global_menu.sh

lab_%-schema: ## Create schema: make lab_2-schema [ARGS=--reset]
	$(call guard,$*)
	./labs/lab_$*/scripts/create_schema.sh $(ARGS)

lab_%-data: ## Insert sample data: make lab_2-data [ARGS=--force]
	$(call guard,$*)
	./labs/lab_$*/scripts/insert_data.sh $(ARGS)

lab_%-explain: ## Run EXPLAIN demos: make lab_2-explain
	$(call guard,$*)
	./labs/lab_$*/scripts/explain_demo.sh

lab_%-indexes: ## Create advanced indexes: make lab_2-indexes
	$(call guard,$*)
	./labs/lab_$*/scripts/create_indexes.sh

lab_%-rewrite: ## Run query rewrite demo: make lab_2-rewrite
	$(call guard,$*)
	./labs/lab_$*/scripts/query_rewrite.sh

lab_%-partition: ## Run partitioning demo: make lab_2-partition [ARGS=--bulk]
	$(call guard,$*)
	./labs/lab_$*/scripts/partitioning_demo.sh $(ARGS)

lab_%-log: ## Log query performance: make lab_2-log [ARGS="--repeat 3 --interval 2"]
	$(call guard,$*)
	./labs/lab_$*/scripts/log_performance.sh $(ARGS)

lab_%-report: ## Show query performance trends: make lab_2-report
	$(call guard,$*)
	./labs/lab_$*/scripts/log_performance.sh --report

lab_%-reset: ## DESTRUCTIVE: recreate only that lab's database
	$(call guard,$*)
	./labs/lab_$*/scripts/create_schema.sh --reset

check: ## Validate shell syntax and compose configuration
	@for f in scripts/*.sh scripts/lib/db.sh \
	          $(wildcard labs/*/config.sh) $(wildcard labs/*/scripts/*.sh) \
	          docker/postgres/initdb/*.sh; do \
		bash -n "$$f" || exit 1; \
	done
	@docker compose config --quiet
	@echo "checks passed"
