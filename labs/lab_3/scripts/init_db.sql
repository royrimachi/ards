CREATE TABLE IF NOT EXISTS account (
  id SERIAL PRIMARY KEY,
  owner_name VARCHAR(100) NOT NULL,
  balance NUMERIC(10, 2) NOT NULL
);

INSERT INTO account (owner_name, balance)
SELECT owner_name, balance
FROM (VALUES
  ('Alice', 1000.00::NUMERIC(10, 2)),
  ('Bob', 800.00::NUMERIC(10, 2))
) AS initial_data(owner_name, balance)
WHERE NOT EXISTS (
  SELECT 1
  FROM account
  WHERE account.owner_name = initial_data.owner_name
);
