#!/usr/bin/env bash
# Interactive menu for the PostgreSQL streaming replication lab.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_script() {
  bash "$SCRIPT_DIR/$1"
}

while true; do
  echo "========================================"
  echo " PostgreSQL Streaming Replication Lab"
  echo "========================================"
  echo "1) Set up Docker environment"
  echo "2) Start master"
  echo "3) Start slave"
  echo "4) Initialize replication"
  echo "5) Test replication"
  echo "6) Simulate failover"
  echo "7) Show service status"
  echo "8) Stop lab services"
  echo "9) Exit"
  read -r -p "Enter choice [1-9]: " choice
  echo

  case "$choice" in
    1) run_script setup_docker_env.sh ;;
    2) run_script start_master.sh ;;
    3) run_script start_slave.sh ;;
    4) run_script init_replication.sh ;;
    5) run_script test_replication.sh ;;
    6) run_script simulate_failover.sh ;;
    7) source "$SCRIPT_DIR/common.sh"; compose_lab4 ps ;;
    8) source "$SCRIPT_DIR/common.sh"; compose_lab4 stop ;;
    9) break ;;
    *) echo "Invalid choice. Please enter a number between 1 and 9." ;;
  esac
  echo
done
