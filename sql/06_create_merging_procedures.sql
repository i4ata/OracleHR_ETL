\! echo '------------------------------------------------------------------------------------------------------------------------------------'
\! echo 'Running create_merging_procedures.sql. Create the necessary functionality for merging the staging tables while supporting SCD Type 2'
\! echo '------------------------------------------------------------------------------------------------------------------------------------'

-- Since MERGE() does not exist in MySQL, I wrote the functionality myself
-- The procedures for all dimensions are analogical (there is a lot of code duplication but there is really no way around it)
-- Again, there is no procedure for the time dimension since we probably don't want to change the time

DELIMITER $$

-- --------- --
-- EMPLOYEES --
-- --------- --
CREATE PROCEDURE merge_employees()
BEGIN
    -- Store the surrogate id's that are currently expiring 
    -- They will be used to update the fact table later
    CREATE TABLE old_surrogate_id (surrogate_employee_id CHAR(32))
    SELECT surrogate_employee_id FROM employee_dim WHERE employee_id IN (SELECT employee_id from staging_employees) AND is_current = TRUE;

    -- Expire the merged rows if their id's are already present
    UPDATE employee_dim JOIN staging_employees USING (employee_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    -- Merge the rows into the dim. This triggers a trigger
    INSERT INTO employee_dim (employee_id, full_name, hire_date, job_id, salary, commission_pct, email, phone_number, manager_id, department_id) 
    SELECT * FROM staging_employees;

    -- Update the fact table by replacing the expired surrogate id's with the new ones. This triggers a trigger
    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id AS old_id USING (surrogate_employee_id)
    JOIN employee_dim AS dim ON dim.employee_id = (SELECT employee_id FROM employee_dim WHERE surrogate_employee_id = old_id.surrogate_employee_id) AND is_current = TRUE
    SET fact.surrogate_employee_id = dim.surrogate_employee_id;

    -- Delete the stored old id's and empty the staging table
    DROP TABLE old_surrogate_id;
    DELETE FROM staging_employees;

END $$

-- ----------- --
-- DEPARTMENTS --
-- ----------- --
CREATE PROCEDURE merge_departments()
BEGIN
    CREATE TABLE old_surrogate_id (surrogate_department_id CHAR(32))
    SELECT surrogate_department_id FROM department_dim WHERE department_id IN (SELECT department_id from staging_departments) AND is_current = TRUE;

    UPDATE department_dim JOIN staging_departments USING (department_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO department_dim (department_id, department_name, location_id, manager_id) 
    SELECT * FROM staging_departments;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id AS old_id USING (surrogate_department_id)
    JOIN department_dim AS dim ON dim.department_id = (SELECT department_id FROM department_dim WHERE surrogate_department_id = old_id.surrogate_department_id) AND is_current = TRUE
    SET fact.surrogate_department_id = dim.surrogate_department_id;

    DROP TABLE old_surrogate_id;
    DELETE FROM staging_departments;

END $$

-- ---- --
-- JOBS --
-- ---- --
CREATE PROCEDURE merge_jobs()
BEGIN
    CREATE TABLE old_surrogate_id (surrogate_job_id CHAR(32))
    SELECT surrogate_job_id FROM job_dim WHERE job_id IN (SELECT job_id from staging_jobs) AND is_current = TRUE;

    UPDATE job_dim JOIN staging_jobs USING (job_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO job_dim (job_id, job_title, min_salary, max_salary) 
    SELECT * FROM staging_jobs;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id AS old_id USING (surrogate_job_id)
    JOIN job_dim AS dim ON dim.job_id = (SELECT job_id FROM job_dim WHERE surrogate_job_id = old_id.surrogate_job_id) AND is_current = TRUE
    SET fact.surrogate_job_id = dim.surrogate_job_id;

    DROP TABLE old_surrogate_id;
    DELETE FROM staging_jobs;

END $$


-- --------- --
-- LOCATIONS --
-- --------- --
CREATE PROCEDURE merge_locations()
BEGIN
    CREATE TABLE old_surrogate_id (surrogate_location_id CHAR(32))
    SELECT surrogate_location_id FROM location_dim WHERE location_id IN (SELECT location_id from staging_locations) AND is_current = TRUE;

    UPDATE location_dim JOIN staging_locations USING (location_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO location_dim (location_id, street_address, postal_code, city, state_province, country_id, country_name, region_id, region_name) 
    SELECT * FROM staging_locations;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id AS old_id USING (surrogate_location_id)
    JOIN location_dim AS dim ON dim.location_id = (SELECT location_id FROM location_dim WHERE surrogate_location_id = old_id.surrogate_location_id) AND is_current = TRUE
    SET fact.surrogate_location_id = dim.surrogate_location_id;

    DROP TABLE old_surrogate_id;
    DELETE FROM staging_locations;

END $$

DELIMITER ;

\! echo 'All merging procedures created successfully'
