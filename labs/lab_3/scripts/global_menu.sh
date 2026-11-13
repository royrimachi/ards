#!/usr/bin/env bash
# labs/lab_3/scripts/global_menu.sh
# Interactive menu for the transactions and concurrency lab.

set -euo pipefail

# Sources use SCRIPT_DIR so the script works from any working directory.
# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../scripts/lib/db.sh
source "$SCRIPT_DIR/../../../scripts/lib/db.sh"
# shellcheck source=../config.sh
source "$SCRIPT_DIR/../config.sh"

run_script() {
  local script="$1"
  shift
  bash "$SCRIPT_DIR/$script" "$@"
}

while true; do
  echo "========================================"
  echo " Transactions & Concurrency Lab"
  echo "========================================"
  echo "Database: $LAB_DB_NAME (shared PostgreSQL service)"
  echo
  echo "1) Start PostgreSQL and initialize the lab database"
  echo "2) Test different isolation levels"
  echo "3) Simulate and log a deadlock"
  echo "4) Demonstrate MVCC"
  echo "5) Run all concurrency logging scenarios"
  echo "6) Show the concurrency conflict report"
  echo "7) Show database status"
  echo "8) Open the lab database shell"
  echo "9) Stop PostgreSQL (keep data)"
  echo "10) Exit"
  echo

  read -r -p "Enter choice [1-10]: " choice
  echo

  case "$choice" in
    1) run_script create_db_env.sh ;;
    2) run_script isolation_levels.sh ;;
    3) run_script simulate_deadlock.sh ;;
    4) run_script mvcc_demo.sh ;;
    5) run_script log_concurrency.sh ;;
    6) run_script log_concurrency.sh --report ;;
    7) db_status ;;
    8) db_shell "$LAB_DB_NAME" ;;
    9) db_stop ;;
    10) echo "Exiting..."; break ;;
    *) echo "Invalid choice. Please enter a number between 1 and 10." ;;
  esac

  echo
done
