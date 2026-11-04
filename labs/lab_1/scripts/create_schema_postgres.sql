CREATE TABLE IF NOT EXISTS departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL,
    location VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    start_date DATE,
    end_date DATE
);

CREATE TABLE IF NOT EXISTS employees (
    emp_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT REFERENCES departments (dept_id),
    hire_date DATE
);

CREATE TABLE IF NOT EXISTS employee_projects (
    emp_id INT NOT NULL REFERENCES employees (emp_id),
    project_id INT NOT NULL REFERENCES projects (project_id),
    role VARCHAR(50),
    PRIMARY KEY (emp_id, project_id)
);

CREATE INDEX IF NOT EXISTS idx_employees_last_name ON employees (last_name);
