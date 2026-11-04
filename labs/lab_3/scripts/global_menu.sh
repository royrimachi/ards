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
  bash "$SCRIPT_DIR/$1"
}

while true; do
  echo "========================================"
  echo " Transactions & Concurrency Lab"
  echo "========================================"
  echo "Database: $LAB_DB_NAME (shared PostgreSQL service)"
  echo
  echo "1) Start PostgreSQL and initialize the lab database"
  echo "2) Test different isolation levels"
  echo "3) Simulate a deadlock"
  echo "4) Demonstrate MVCC"
  echo "5) Show database status"
  echo "6) Open the lab database shell"
  echo "7) Stop PostgreSQL (keep data)"
  echo "8) Exit"
  echo

  read -r -p "Enter choice [1-8]: " choice
  echo

  case "$choice" in
    1) run_script create_db_env.sh ;;
    2) run_script isolation_levels.sh ;;
    3) run_script simulate_deadlock.sh ;;
    4) run_script mvcc_demo.sh ;;
    5) db_status ;;
    6) db_shell "$LAB_DB_NAME" ;;
    7) db_stop ;;
    8) echo "Exiting..."; break ;;
    *) echo "Invalid choice. Please enter a number between 1 and 8." ;;
  esac

  echo
done
