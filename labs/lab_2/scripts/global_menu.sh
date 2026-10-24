#!/usr/bin/env bash
# global_menu.sh
# Interactive menu for the SQL Optimization Lab.
# Every option delegates to a script that uses the project-wide database layer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

show_menu() {
  echo "==================================================="
  echo " SQL Optimization Lab - Global Script Menu"
  echo "==================================================="
  echo "Database: $LAB_DB_NAME (shared instance on port $POSTGRES_PORT)"
  echo "---------------------------------------------------"
  echo " 1) Start PostgreSQL and provision the lab database"
  echo " 2) Create database schema"
  echo " 3) Insert sample data"
  echo " 4) Run basic EXPLAIN/EXPLAIN ANALYZE demos"
  echo " 5) Create advanced indexes"
  echo " 6) Demonstrate query rewriting"
  echo " 7) Optional: demonstrate partitioning"
  echo " 8) Log query performance (EXPLAIN ANALYZE)"
  echo " 9) Show query performance report"
  echo "10) Reset the lab database (drop and recreate)"
  echo "11) Show database status"
  echo "12) Open psql shell for the lab database"
  echo "13) Stop PostgreSQL (keep data)"
  echo "14) Exit"
  echo "---------------------------------------------------"
}

run_script() {
  local script="$1"
  shift
  bash "$SCRIPT_DIR/$script" "$@"
}

while true; do
  show_menu
  read -r -p "Enter your choice [1-14]: " choice
  echo

  case "$choice" in
    1)  run_script start_container.sh ;;
    2)  run_script create_schema.sh ;;
    3)  run_script insert_data.sh ;;
    4)  run_script explain_demo.sh ;;
    5)  run_script create_indexes.sh ;;
    6)  run_script query_rewrite.sh ;;
    7)  run_script partitioning_demo.sh ;;
    8)  run_script log_performance.sh ;;
    9)  run_script log_performance.sh --report ;;
    10) run_script create_schema.sh --reset ;;
    11) bash "$PROJECT_ROOT/scripts/db-status.sh" ;;
    12) bash "$PROJECT_ROOT/scripts/db-shell.sh" "$LAB_DB_NAME" ;;
    13) run_script stop_container.sh ;;
    14) echo "Exiting..."; break ;;
    *)  echo "Invalid choice. Please enter a number between 1 and 14." ;;
  esac

  echo
done
