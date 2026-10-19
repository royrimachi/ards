-- insert_data.sql
-- Inserts sample department data, then generates 20,000 random employee rows.
-- Departments are only inserted when missing, so a re-run does not duplicate them.

-- 1) Insert the departments required by the sample data
INSERT INTO departments (dept_name, location)
SELECT v.dept_name, v.location
FROM (VALUES
    ('Sales', 'New York'),
    ('Engineering', 'San Francisco'),
    ('Marketing', 'London'),
    ('Finance', 'Paris'),
    ('HR', 'Madrid'),
    ('Quality Assurance', 'Berlin'),
    ('Support', 'Tokyo')
) AS v(dept_name, location)
WHERE NOT EXISTS (
    SELECT 1
    FROM departments d
    WHERE d.dept_name = v.dept_name
);

-- 2) Insert 20,000 employees using random data
DO $$
DECLARE
    i INT;

    someFirstNames TEXT[] := ARRAY[
        'John','Jane','Alice','Bob','Carlos','Diana','Eduardo','Fiona',
        'Gina','Hector','Irene','Jack','Kelly','Luis','Mona','Nina',
        'Omar','Paula','Rafael','Sasha','Tania','Ulysses','Vera','Wendy',
        'Xavier','Yara','Zack'
    ];
    someLastNames TEXT[] := ARRAY[
        'Smith','Johnson','Garcia','Martinez','Brown','Williams','Jones',
        'Miller','Davis','Lopez','Thomas','Gonzalez','Wilson','Anderson',
        'Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson','White',
        'Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker'
    ];
    someDeptNames TEXT[] := ARRAY[
        'Sales','Engineering','Marketing','Finance','HR','Quality Assurance','Support'
    ];

    rFirstName TEXT;
    rLastName TEXT;
    rDeptName TEXT;
    rDeptID INT;
BEGIN
    FOR i IN 1..20000 LOOP
        -- Pick a random first name
        rFirstName := someFirstNames[(floor(random() * array_length(someFirstNames, 1)) + 1)::INT];
        -- Pick a random last name
        rLastName := someLastNames[(floor(random() * array_length(someLastNames, 1)) + 1)::INT];
        -- Pick a random department name
        rDeptName := someDeptNames[(floor(random() * array_length(someDeptNames, 1)) + 1)::INT];

        -- Retrieve the corresponding department ID
        SELECT id
        INTO rDeptID
        FROM departments
        WHERE dept_name = rDeptName
        LIMIT 1;

        -- Insert into employees
        INSERT INTO employees(
            first_name,
            last_name,
            department,
            department_id,
            email
        )
        VALUES (
            rFirstName,
            rLastName,
            rDeptName,
            rDeptID,
            LOWER(rFirstName || '.' || rLastName || '@example.com')
        );
    END LOOP;
END;
$$;
