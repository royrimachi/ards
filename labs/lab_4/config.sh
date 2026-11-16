#!/usr/bin/env bash
# labs/lab_4/config.sh
# Lab-specific configuration for PostgreSQL streaming replication.

LAB4_COMPOSE_FILE="${LAB4_COMPOSE_FILE:-$PROJECT_ROOT/compose.yaml}"
LAB4_PROJECT_NAME="${LAB4_PROJECT_NAME:-ards-lab4}"
LAB4_MASTER_SERVICE="${LAB4_MASTER_SERVICE:-master}"
LAB4_SLAVE_SERVICE="${LAB4_SLAVE_SERVICE:-slave}"
LAB4_REPLICATION_USER="${LAB4_REPLICATION_USER:-repuser}"
LAB4_REPLICATION_PASSWORD="${LAB4_REPLICATION_PASSWORD:-reppass}"
LAB4_DATABASE="${LAB4_DATABASE:-replication_db}"
