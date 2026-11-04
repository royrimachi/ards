CREATE TABLE IF NOT EXISTS departments (
    dept_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL,
    location VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS projects (
    project_id INT AUTO_INCREMENT PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    start_date DATE,
    end_date DATE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS employees (
    emp_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    hire_date DATE,
    CONSTRAINT fk_department FOREIGN KEY (department_id)
        REFERENCES departments (dept_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS employee_projects (
    emp_id INT NOT NULL,
    project_id INT NOT NULL,
    role VARCHAR(50),
    PRIMARY KEY (emp_id, project_id),
    CONSTRAINT fk_emp FOREIGN KEY (emp_id) REFERENCES employees (emp_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_proj FOREIGN KEY (project_id) REFERENCES projects (project_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

SET @index_exists = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'employees'
      AND index_name = 'idx_employees_last_name'
);
SET @create_index = IF(
    @index_exists = 0,
    'CREATE INDEX idx_employees_last_name ON employees (last_name)',
    'SELECT 1'
);
PREPARE create_index FROM @create_index;
EXECUTE create_index;
DEALLOCATE PREPARE create_index;
