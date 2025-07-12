\! echo '------------------------------------------------------------------------------------'
\! echo 'Running merge_staging_tables.sql. Merge the staging tables and verify SCD2 integrity'
\! echo '------------------------------------------------------------------------------------'

-- --------- --
-- EMPLOYEES --
-- --------- --

-- necessary to make a copy of the staging table since the original table is deleted upon merging
CREATE TABLE staging_employees_copy SELECT * FROM staging_employees;

\! echo 'About to merge employees. Expired records before merging:'
SELECT surrogate_employee_id, employee_id, full_name, salary, commission_pct, effective_start_date, effective_end_date, is_current 
FROM employee_dim WHERE employee_id IN (SELECT employee_id FROM staging_employees_copy);

\! echo 'Fact table before merging:'
SELECT surrogate_employee_id, employee_id, full_name, employee_yearly_salary_fact.salary as yearly_salary, bonus, commission_pct, total_compensation 
FROM employee_yearly_salary_fact JOIN employee_dim USING (surrogate_employee_id) WHERE employee_id IN (SELECT employee_id FROM staging_employees_copy);

\! echo 'Merging ...'
CALL merge_employees();

\! echo 'Affected records after merging:'
SELECT surrogate_employee_id, employee_id, full_name, salary, commission_pct, effective_start_date, effective_end_date, is_current 
FROM employee_dim WHERE employee_id IN (SELECT employee_id FROM staging_employees_copy);

\! echo 'Fact table after merging:'
SELECT surrogate_employee_id, employee_id, full_name, employee_yearly_salary_fact.salary as yearly_salary, bonus, commission_pct, total_compensation 
FROM employee_yearly_salary_fact JOIN employee_dim USING (surrogate_employee_id) WHERE employee_id IN (SELECT employee_id FROM staging_employees_copy);
\! echo 'Note that the old surrogate ids are inclded in the join. They would have appeared if they were present in the fact table'

-- ----------- --
-- DEPARTMENTS --
-- ----------- --

CREATE TABLE staging_departments_copy SELECT * FROM staging_departments;

\! echo 'About to merge departments. Expired records before merging:'
SELECT surrogate_department_id, department_id, department_name, effective_start_date, effective_end_date, is_current
FROM department_dim WHERE department_id in (SELECT department_id FROM staging_departments_copy);

\! echo 'Fact table before merging:'
SELECT surrogate_department_id, department_id, department_name
FROM employee_yearly_salary_fact JOIN department_dim USING (surrogate_department_id) WHERE department_id IN (SELECT department_id FROM staging_departments_copy);

\! echo 'Merging ...'
CALL merge_departments();

\! echo 'Affected records after merging:'
SELECT surrogate_department_id, department_id, department_name, effective_start_date, effective_end_date, is_current 
FROM department_dim WHERE department_id IN (SELECT department_id FROM staging_departments_copy);

\! echo 'Fact table after merging:'
SELECT surrogate_department_id, department_id, department_name, is_current
FROM employee_yearly_salary_fact JOIN department_dim USING (surrogate_department_id) WHERE department_id IN (SELECT department_id FROM staging_departments_copy);

-- ---- --
-- JOBS --
-- ---- --

CREATE TABLE staging_jobs_copy SELECT * FROM staging_jobs;

\! echo 'About to merge jobs. Expired records before merging:'
SELECT surrogate_job_id, job_id, job_title, min_salary, max_salary, effective_start_date, effective_end_date, is_current
FROM job_dim WHERE job_id in (SELECT job_id FROM staging_jobs_copy);

\! echo 'Fact table before merging:'
SELECT surrogate_job_id, job_id, job_title, min_salary, max_salary
FROM employee_yearly_salary_fact JOIN job_dim USING (surrogate_job_id) WHERE job_id IN (SELECT job_id FROM staging_jobs_copy);

\! echo 'Merging ...'
CALL merge_jobs();

\! echo 'Affected records after merging:'
SELECT surrogate_job_id, job_id, job_title, min_salary, max_salary, effective_start_date, effective_end_date, is_current
FROM job_dim WHERE job_id IN (SELECT job_id FROM staging_jobs_copy);

\! echo 'Fact table after merging:'
SELECT surrogate_job_id, job_id, job_title, min_salary, max_salary, is_current
FROM employee_yearly_salary_fact JOIN job_dim USING (surrogate_job_id) WHERE job_id IN (SELECT job_id FROM staging_jobs_copy);

-- --------- --
-- LOCATIONS --
-- --------- --

CREATE TABLE staging_locations_copy SELECT * FROM staging_locations;

\! echo 'About to merge locations. Expired records before merging:'
SELECT surrogate_location_id, location_id, city, country_id, country_name, effective_start_date, effective_end_date, is_current
FROM location_dim WHERE location_id in (SELECT location_id FROM staging_locations_copy);

\! echo 'Fact table before merging:'
SELECT surrogate_location_id, location_id, city, country_id, country_name
FROM employee_yearly_salary_fact JOIN location_dim USING (surrogate_location_id) WHERE location_id IN (SELECT location_id FROM staging_locations_copy);

\! echo 'Merging ...'
CALL merge_locations();

\! echo 'Affected records after merging:'
SELECT surrogate_location_id, location_id, city, country_id, country_name, effective_start_date, effective_end_date, is_current
FROM location_dim WHERE location_id in (SELECT location_id FROM staging_locations_copy);

\! echo 'Fact table after merging:'
SELECT surrogate_location_id, location_id, city, country_id, country_name, is_current
FROM employee_yearly_salary_fact JOIN location_dim USING (surrogate_location_id) WHERE location_id IN (SELECT location_id FROM staging_locations_copy);

\! echo 'All staging tables merge successfully'
