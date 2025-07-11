SET GLOBAL local_infile=ON;

-- --------- --
-- LOCATIONS --
-- --------- --
CREATE TABLE regions_temp (
    region_id DECIMAL,
    region_name VARCHAR(25)
);

LOAD DATA LOCAL INFILE 'data/regions.csv' INTO TABLE regions_temp
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (region_id, region_name);

CREATE TABLE countries_temp (
    country_id CHAR(2),
    country_name VARCHAR(52), -- So that it fits UK
    region_id DECIMAL
);

LOAD DATA LOCAL INFILE 'data/countries.csv' INTO TABLE countries_temp
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (country_id, country_name, region_id);

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

INSERT INTO location_dim SELECT
    MD5(CONCAT(location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name)) AS surrogate_location_id, 
    location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name 
    FROM locations_temp JOIN countries_temp USING (country_id) JOIN regions_temp USING (region_id);

DROP TABLE regions_temp;
DROP TABLE countries_temp;
DROP TABLE locations_temp;

-- ---- --
-- JOBS --
-- ---- --
LOAD DATA LOCAL INFILE 'data/jobs.csv' INTO TABLE job_dim
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (job_id, job_title, min_salary, max_salary)
    SET 
        job_category = CASE
            WHEN job_title LIKE '%President%'  OR job_title LIKE '%Manager%'                                         THEN 'Management'
            WHEN job_title LIKE '%Programmer%' OR job_title LIKE '%Accountant%' OR job_title LIKE '%Representative%' THEN 'Technical/Professional'
            WHEN job_title LIKE '%Assistant%'  OR job_title LIKE '%Clerk%'                                           THEN 'Clerical/Support'
                                                                                                                     ELSE 'Other'
        END,
        surrogate_job_id = MD5(CONCAT(
            job_id, job_title, min_salary, max_salary, job_category, job_category
        ));

-- --------- --
-- EMPLOYEES --
-- --------- --

SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA LOCAL INFILE 'data/employees.csv' INTO TABLE employee_dim
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (employee_id, @first_name, @last_name, @email, @phone_number, @hire_date, job_id, salary, @commission_pct, @manager_id, @department_id)
    SET
        hire_date = DATE(REGEXP_REPLACE(@hire_date, 'T.*', '')),
        full_name = CONCAT(@first_name, ' ', @last_name),
        email = CONCAT(@email, '@egt.com'),
        phone_number = CONCAT('+359', REGEXP_REPLACE(REGEXP_REPLACE(@phone_number, '^.*?\\.', ''), '\\.', '')),
        surrogate_employee_id = MD5(CONCAT(
            employee_id, full_name, hire_date, job_id, salary, @commission_pct, email, phone_number, @manager_id, @department_id
        )),
        manager_id = NULLIF(@manager_id, ''),
        commission_pct = IF(@commission_pct = '', DEFAULT(commission_pct), @commission_pct),
        department_id = NULLIF(@department_id, '');

-- can't do that in SET from above
WITH tenure AS (SELECT employee_id, TIMESTAMPDIFF(YEAR, hire_date, CURDATE()) as years from employee_dim)
    UPDATE employee_dim JOIN tenure USING (employee_id) SET tenure_band = CASE 
        WHEN years < 1              THEN 'Less than 1 year'
        WHEN years BETWEEN 1 and 3  THEN '1-3 years'
        WHEN years BETWEEN 4 and 6  THEN '4-6 years'
        WHEN years BETWEEN 7 and 10 THEN '7-10 years'
        WHEN years > 10             THEN '10+ years'
        ELSE NULL
    END;

SET FOREIGN_KEY_CHECKS = 1;

-- ----------- --
-- DEPARTMENTS --
-- ----------- --
LOAD DATA LOCAL INFILE 'data/departments.csv' INTO TABLE department_dim
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
    (department_id, department_name, @manager_id, location_id)
    SET 
        manager_id = NULLIF(@manager_id, ''),
        surrogate_department_id = MD5(CONCAT(
            department_id, department_name, location_id, @manager_id
        ));

-- ----- --
-- TIMES --
-- ----- --
source ./sql/time_dim.sql

-- ---------------------------- --
-- EMPLOYEES YEARLY SALARY FACT --
-- ---------------------------- --
INSERT INTO employee_yearly_salary_fact
WITH
    all_employees AS (
        SELECT
            YEAR(hire_date) as hiring_year, 
            surrogate_employee_id, surrogate_department_id, surrogate_job_id, surrogate_location_id,
            (salary * 12) as salary, 
            (salary * 12 * commission_pct) as bonus, 
            (salary * 12 * commission_pct + salary * 12) as total_compensation,
            CURDATE() as effective_date
        FROM
            employee_dim 
            JOIN department_dim USING (department_id) 
            JOIN job_dim USING (job_id) 
            JOIN location_dim USING (location_id)
    ),
    all_years AS (
        SELECT surrogate_time_id, year from time_dim WHERE day = 31 AND month = 12
    ),
    salary_data as (
        SELECT
            MD5(CONCAT(surrogate_employee_id, surrogate_department_id, surrogate_job_id, surrogate_time_id, surrogate_location_id, salary, bonus, total_compensation, effective_date)) as surrogate_fact_id,
            surrogate_employee_id, surrogate_department_id, surrogate_job_id, surrogate_time_id, surrogate_location_id, salary, bonus, total_compensation, effective_date
        FROM all_employees JOIN all_years ON all_employees.hiring_year <= all_years.year ORDER BY surrogate_employee_id, year
    )
SELECT * FROM salary_data;
