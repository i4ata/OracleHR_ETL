CREATE TABLE staging_employees (
    employee_id DECIMAL(6,0) UNIQUE NOT NULL, -- UNIQUE here prevents updating the same employee multiple times within a single merge
    full_name VARCHAR(41),
    hire_date DATE,
    job_id VARCHAR(10),
    salary DECIMAL(8,2),
    commission_pct DECIMAL(2,2) DEFAULT 0,
    email VARCHAR(33),
    phone_number VARCHAR(20),
    manager_id DECIMAL(6,0),
    department_id DECIMAL(4,0)
)
SELECT employee_id, full_name, hire_date, job_id, salary, commission_pct, email, phone_number, manager_id, department_id 
FROM employee_dim WHERE employee_id in (102, 103);
UPDATE staging_employees SET full_name = 'Kristian Kiradjiev', commission_pct = 0.1 WHERE employee_id = 102;
UPDATE staging_employees SET full_name = 'Radosvet Yosifov ', salary = 20000 WHERE employee_id = 103;

CREATE TABLE staging_departments (
    department_id DECIMAL(6,0) UNIQUE NOT NULL,
    department_name VARCHAR(30),
    location_id DECIMAL(4,0),
    manager_id DECIMAL(6,0)
)
SELECT department_id, department_name, location_id, manager_id 
FROM department_dim WHERE department_id in (130, 140);
UPDATE staging_departments SET department_name = 'EGT';

CREATE TABLE staging_jobs (
    job_id VARCHAR(10) UNIQUE NOT NULL,
    job_title VARCHAR(35),
    min_salary DECIMAL(6,0),
    max_salary DECIMAL(6,0)
)
SELECT job_id, job_title, min_salary, max_salary 
FROM job_dim WHERE job_id in ('AD_PRES', 'AD_VP', 'FI_ACCOUNT');
UPDATE staging_jobs SET min_salary = 100;

CREATE TABLE staging_locations (
    location_id DECIMAL(4,0) UNIQUE NOT NULL,
    street_address VARCHAR(40),
    postal_code VARCHAR(12),
    city VARCHAR(30),
    state_province VARCHAR(25),
    country_id CHAR(2),
    country_name VARCHAR(52),
    region_id DECIMAL,
    region_name VARCHAR(25)
)
SELECT location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name 
FROM location_dim WHERE location_id = 2200;
UPDATE staging_locations SET city = 'Sofia', country_id = 'BG';

DELIMITER $$

-- BUG: This breaks if an already expired row is attempted to be remerged
CREATE PROCEDURE merge_employees()
BEGIN

    -- Delete rows that are already in the employee_dim table as it's pointless to merge them. Sucks to calculate their surrogate indicies again
    DELETE FROM staging_employees WHERE MD5(CONCAT(
        employee_id, full_name, hire_date, job_id, salary, 
        COALESCE(commission_pct, ''), email, phone_number, COALESCE(manager_id, ''), COALESCE(department_id, '')
    )) IN (SELECT surrogate_employee_id FROM employee_dim WHERE is_current = TRUE);

    CREATE TABLE old_surrogate_id (surrogate_employee_id CHAR(32))
    SELECT surrogate_employee_id FROM employee_dim WHERE employee_id IN (SELECT employee_id from staging_employees) AND is_current = TRUE;

    UPDATE employee_dim JOIN staging_employees USING (employee_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO employee_dim (employee_id, full_name, hire_date, job_id, salary, commission_pct, email, phone_number, manager_id, department_id) 
    SELECT * FROM staging_employees;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id USING (surrogate_employee_id)
    JOIN employee_dim AS dim ON dim.employee_id IN (SELECT employee_id FROM staging_employees) AND is_current = TRUE
    SET fact.surrogate_employee_id = dim.surrogate_employee_id;

    DROP TABLE old_surrogate_id;

END $$

CREATE PROCEDURE merge_departments()
BEGIN

    DELETE FROM staging_departments WHERE MD5(CONCAT(department_id, department_name, location_id, COALESCE(manager_id, ''))) 
    IN (SELECT surrogate_department_id FROM department_dim WHERE is_current = TRUE);

    CREATE TABLE old_surrogate_id (surrogate_department_id CHAR(32))
    SELECT surrogate_department_id FROM department_dim WHERE department_id IN (SELECT department_id from staging_departments) AND is_current = TRUE;

    UPDATE department_dim JOIN staging_departments USING (department_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO department_dim (department_id, department_name, location_id, manager_id) 
    SELECT * FROM staging_departments;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id USING (surrogate_department_id)
    JOIN department_dim AS dim ON dim.department_id IN (SELECT department_id FROM staging_departments) AND is_current = TRUE
    SET fact.surrogate_department_id = dim.surrogate_department_id;

    DROP TABLE old_surrogate_id;

END $$


CREATE PROCEDURE merge_jobs()
BEGIN

    DELETE FROM staging_jobs WHERE MD5(CONCAT(job_id, job_title, min_salary, max_salary)) 
    IN (SELECT surrogate_job_id FROM job_dim WHERE is_current = TRUE);

    CREATE TABLE old_surrogate_id (surrogate_job_id CHAR(32))
    SELECT surrogate_job_id FROM job_dim WHERE job_id IN (SELECT job_id from staging_jobs) AND is_current = TRUE;

    UPDATE job_dim JOIN staging_jobs USING (job_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO job_dim (job_id, job_title, min_salary, max_salary) 
    SELECT * FROM staging_jobs;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id USING (surrogate_job_id)
    JOIN job_dim AS dim ON dim.job_id IN (SELECT job_id FROM staging_jobs) AND is_current = TRUE
    SET fact.surrogate_job_id = dim.surrogate_job_id;

    DROP TABLE old_surrogate_id;

END $$


CREATE PROCEDURE merge_locations()
BEGIN

    DELETE FROM staging_locations WHERE MD5(CONCAT(location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name)) 
    IN (SELECT surrogate_location_id FROM location_dim WHERE is_current = TRUE);

    CREATE TABLE old_surrogate_id (surrogate_location_id CHAR(32))
    SELECT surrogate_location_id FROM location_dim WHERE location_id IN (SELECT location_id from staging_locations) AND is_current = TRUE;

    UPDATE location_dim JOIN staging_locations USING (location_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO location_dim (location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name) 
    SELECT * FROM staging_locations;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id USING (surrogate_location_id)
    JOIN location_dim AS dim ON dim.location_id IN (SELECT location_id FROM staging_locations) AND is_current = TRUE
    SET fact.surrogate_location_id = dim.surrogate_location_id;

    DROP TABLE old_surrogate_id;

END $$

DELIMITER ;

CALL merge_employees();
CALL merge_departments();
CALL merge_jobs();
CALL merge_locations();
