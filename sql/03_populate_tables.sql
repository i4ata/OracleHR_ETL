\! echo '------------------------------------------------------------------------------'
\! echo 'Running populate_tables.sql. Use the provided CSV files to populate the tables'
\! echo '------------------------------------------------------------------------------'

-- Directly populate the tables using the CSVs

SET GLOBAL local_infile=ON; -- enable loading the data from files

-- --------- --
-- EMPLOYEES --
-- --------- --
LOAD DATA LOCAL INFILE 'data/employees.csv' INTO TABLE employee_dim
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (employee_id, @first_name, @last_name, @email, @phone_number, @hire_date, job_id, salary, @commission_pct, @manager_id, @department_id)
    SET
        hire_date = DATE(REGEXP_REPLACE(@hire_date, 'T.*', '')), -- remove the time, keep only the date
        full_name = CONCAT(@first_name, ' ', @last_name),
        email = CONCAT(@email, '@egt.com'),
        phone_number = CONCAT('+359', REGEXP_REPLACE(REGEXP_REPLACE(@phone_number, '^.*?\\.', ''), '\\.', '')),
        -- Unfortunately LOAD DATA interprets only the \N character as NULL. A missing value is read as ''. 
        -- That is why here it is manually set to NULL. The same is applied in all dims
        manager_id = NULLIF(@manager_id, ''),
        commission_pct = IF(@commission_pct = '', DEFAULT(commission_pct), @commission_pct),
        department_id = NULLIF(@department_id, '');

\! echo 'Employee dim populated successfully'

-- ----------- --
-- DEPARTMENTS --
-- ----------- --
LOAD DATA LOCAL INFILE 'data/departments.csv' INTO TABLE department_dim
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (department_id, department_name, @manager_id, location_id)
    SET 
        manager_id = NULLIF(@manager_id, '');

\! echo 'Department dim populated successfully'

-- ---- --
-- JOBS --
-- ---- --
LOAD DATA LOCAL INFILE 'data/jobs.csv' INTO TABLE job_dim
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (job_id, job_title, min_salary, max_salary);

\! echo 'Job dim populated successfully'

-- ----- --
-- TIMES --
-- ----- --
INSERT INTO time_dim
-- Hacky way to get all dates between two dates (>200x speedup compared to the provided method)
-- https://stackoverflow.com/questions/9295616/how-to-get-list-of-dates-between-two-dates-in-mysql-select-query
WITH dates AS (
    select * from 
    (select adddate('1995-01-01',t4.i*10000 + t3.i*1000 + t2.i*100 + t1.i*10 + t0.i) dates from
    (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t0,
    (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t1,
    (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t2,
    (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t3,
    (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t4) v
    where dates between '1995-01-01' and '2024-12-31'
)
-- end
SELECT
    CRC32(DATE_FORMAT(dates, '%Y%m%d')),
    DATE_FORMAT(dates, '%Y%m%d'),
    dates,
    YEAR(dates),
    QUARTER(dates),
    MONTH(dates),
    WEEK(dates, 3),
    DAY(dates),
    DAYNAME(dates),
    YEAR(dates),
    QUARTER(dates)
FROM dates;

\! echo 'Time dim populated successfully'

-- --------- --
-- LOCATIONS --
-- --------- --

-- Temporary table for the regions
CREATE TABLE regions_temp (
    region_id DECIMAL,
    region_name VARCHAR(25)
);

LOAD DATA LOCAL INFILE 'data/regions.csv' INTO TABLE regions_temp
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (region_id, region_name);

-- Temporary table for the countries
CREATE TABLE countries_temp (
    country_id CHAR(2),
    country_name VARCHAR(52), -- Increased so that it fits UK
    region_id DECIMAL
);

LOAD DATA LOCAL INFILE 'data/countries.csv' INTO TABLE countries_temp
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (country_id, country_name, region_id);

-- Temporary table for the locations
CREATE TABLE locations_temp (
    location_id DECIMAL(4,0),
    street_address VARCHAR(40),
    postal_code VARCHAR(12),
    city VARCHAR(30),
    state_province VARCHAR(25),
    country_id CHAR(2)
);

LOAD DATA LOCAL INFILE 'data/locations.csv'
    INTO TABLE locations_temp
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (location_id, street_address, postal_code, city, state_province, country_id);

-- Join them all together
INSERT INTO location_dim (location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name) 
    SELECT location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name 
    FROM locations_temp JOIN countries_temp USING (country_id) JOIN regions_temp USING (region_id);

-- Drop the temporary tables
DROP TABLE regions_temp;
DROP TABLE countries_temp;
DROP TABLE locations_temp;

\! echo 'Location dim populated successfully'

-- ---------------------------- --
-- EMPLOYEES YEARLY SALARY FACT --
-- ---------------------------- --

-- Join the tables into the fact table
INSERT INTO employee_yearly_salary_fact (surrogate_employee_id, surrogate_department_id, surrogate_job_id, surrogate_time_id, surrogate_location_id, salary)
WITH
    
    -- Relevant information for each employee
    all_employees AS (
        SELECT YEAR(hire_date) as hiring_year, salary, surrogate_employee_id, surrogate_department_id, surrogate_job_id, surrogate_location_id
        FROM
            employee_dim 
            JOIN department_dim USING (department_id) 
            JOIN job_dim USING (job_id) 
            JOIN location_dim USING (location_id)
    ),
    
    -- The id's of all 31sts of December
    all_years AS (SELECT surrogate_time_id, year from time_dim WHERE day = 31 AND month = 12),

    -- Join them, with 1 row for each employee for each year since their hiring date
    salary_data as (
        SELECT
            surrogate_employee_id, surrogate_department_id, surrogate_job_id, surrogate_time_id, surrogate_location_id, salary
        FROM 
            all_employees 
            JOIN all_years ON all_employees.hiring_year <= all_years.year 
            ORDER BY surrogate_employee_id, year
    )
SELECT * FROM salary_data;

\! echo 'Employee yearly salary fact populated successfully'
