#!/usr/bin/env bash
# labs/lab_2/config.sh
# Lab-specific configuration. The database lives inside the project-wide
# PostgreSQL instance managed by the root compose.yaml.

LAB_DB_NAME="${LAB_DB_NAME:-optimization_db}"
