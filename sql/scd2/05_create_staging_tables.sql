\! echo '---------------------------------------------------------------------------------------------------'
\! echo 'Running create_staging_tables.sql. Created example staging tables to be merged with artificial data'
\! echo '---------------------------------------------------------------------------------------------------'

-- This script creates a staging table for each dimension and gives it some random data (rows to be merged)
-- The staging tables match the structure of the original tables (at least the columns that are not filled automatically)
-- I don't have a staging table for time since we probably don't want to change the time, however, the process would be the same

-- --------- --
-- EMPLOYEES --
-- --------- --
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
UPDATE staging_employees SET full_name = 'Kristian Kiradjiev', commission_pct = 0.1, manager_id = 103 WHERE employee_id = 102;
UPDATE staging_employees SET full_name = 'Radosvet Yosifov ', salary = 20000 WHERE employee_id = 103;

\! echo 'Staging employees table'
SELECT * from staging_employees;

-- ----------- --
-- DEPARTMENTS --
-- ----------- --
CREATE TABLE staging_departments (
    department_id DECIMAL(6,0) UNIQUE NOT NULL,
    department_name VARCHAR(30),
    location_id DECIMAL(4,0),
    manager_id DECIMAL(6,0)
)
SELECT department_id, department_name, location_id, manager_id 
FROM department_dim WHERE department_id in (90, 60);
UPDATE staging_departments SET department_name = 'EGT';

\! echo 'Staging departments table'
SELECT * from staging_departments;

-- ---- --
-- JOBS --
-- ---- --
CREATE TABLE staging_jobs (
    job_id VARCHAR(10) UNIQUE NOT NULL,
    job_title VARCHAR(35),
    min_salary DECIMAL(6,0),
    max_salary DECIMAL(6,0)
)
SELECT job_id, job_title, min_salary, max_salary 
FROM job_dim WHERE job_id in ('AD_PRES', 'AD_VP', 'FI_ACCOUNT');
UPDATE staging_jobs SET min_salary = 100;

\! echo 'Staging jobs table'
SELECT * from staging_jobs;

-- --------- --
-- LOCATIONS --
-- --------- --
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
FROM location_dim WHERE location_id = 2400;
UPDATE staging_locations SET city = 'Sofia', country_id = 'BG', country_name = 'Bulgaria';

\! echo 'Staging locations table'
SELECT * from staging_locations;

\! echo 'All staging tables have been created successfully'
