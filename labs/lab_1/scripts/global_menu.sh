#!/usr/bin/env bash
# Interactive menu for the DBMS Internals lab.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

run_script() {
  local script="$1"
  shift
  bash "$SCRIPT_DIR/$script" "$@"
}

while true; do
  echo "=============================================="
  echo " DBMS Internals Lab - Global Script Menu"
  echo "=============================================="
  echo "Database: $LAB_DB_NAME (shared MySQL service)"
  echo "1) Start MySQL"
  echo "2) Create MySQL schema"
  echo "3) Insert MySQL sample data"
  echo "4) Run MySQL metadata queries"
  echo "5) Reset MySQL database and schema"
  echo "6) Start PostgreSQL"
  echo "7) Create PostgreSQL schema"
  echo "8) Insert PostgreSQL sample data"
  echo "9) Run PostgreSQL metadata queries"
  echo "10) Reset PostgreSQL database and schema"
  echo "11) Stop database services"
  echo "12) Exit"
  read -r -p "Enter your choice [1-12]: " choice
  echo

  case "$choice" in
    1) run_script start_container.sh ;;
    2) run_script create_schema.sh ;;
    3) run_script insert_data.sh ;;
    4) run_script metadata_queries.sh ;;
    5) run_script create_schema.sh --reset ;;
    6) bash "$SCRIPT_DIR/../../../scripts/db-up.sh" ;;
    7) run_script create_schema_postgres.sh ;;
    8) run_script insert_data_postgres.sh ;;
    9) run_script metadata_queries_postgres.sh ;;
    10) run_script create_schema_postgres.sh --reset ;;
    11)
      run_script stop_container.sh
      bash "$SCRIPT_DIR/../../../scripts/db-stop.sh"
      ;;
    12) echo "Exiting..."; break ;;
    *) echo "Invalid choice. Please enter a number between 1 and 12." ;;
  esac
  echo
done
