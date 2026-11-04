INSERT INTO departments (dept_name, location) VALUES
    ('Sales', 'Building A'),
    ('Engineering', 'Building B'),
    ('HR', 'Building C'),
    ('Marketing', 'Building D');

INSERT INTO projects (project_name, start_date, end_date) VALUES
    ('Project Alpha', '2023-01-01', '2023-06-30'),
    ('Project Beta', '2023-02-15', '2023-12-31'),
    ('Project Gamma', '2023-03-01', NULL);

INSERT INTO employees (first_name, last_name, department_id, hire_date) VALUES
    ('Alice', 'Brown', 1, '2022-05-01'),
    ('Bob', 'Smith', 2, '2021-04-20'),
    ('Carol', 'Johnson', 2, '2023-01-15'),
    ('David', 'Miller', 3, '2020-12-01'),
    ('Eve', 'Davis', 1, '2019-10-30'),
    ('Frank', 'Wilson', 4, '2021-11-11'),
    ('Grace', 'Taylor', 2, '2022-03-14'),
    ('Hank', 'Anderson', 4, '2023-02-01'),
    ('Irene', 'Thomas', 3, '2022-07-07'),
    ('Jack', 'Garcia', 1, '2023-01-01');

INSERT INTO employee_projects (emp_id, project_id, role) VALUES
    (1, 1, 'Developer'),
    (2, 2, 'Lead'),
    (3, 1, 'Tester'),
    (3, 2, 'Developer'),
    (4, 2, 'HR Coordinator'),
    (5, 1, 'Sales Rep'),
    (6, 3, 'Coordinator'),
    (7, 2, 'Engineer'),
    (7, 3, 'Engineer'),
    (8, 1, 'Marketer'),
    (9, 1, 'HR Rep'),
    (10, 3, 'Sales Specialist');
