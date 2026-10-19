-- create_tables.sql
-- Creates the lab_2 tables: departments and employees.
-- Safe to re-run: existing tables are left untouched.

CREATE TABLE IF NOT EXISTS departments (
    id        SERIAL PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL,
    location  VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS employees (
    id            SERIAL PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    department    VARCHAR(50) NOT NULL,
    department_id INT REFERENCES departments(id),
    email         VARCHAR(255)
);
