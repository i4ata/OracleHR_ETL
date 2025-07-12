CREATE TABLE staging (
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

UPDATE staging SET commission_pct = 0.1;

DELIMITER $$

-- BUG: This breaks if an expired row is attempted to be remerged
CREATE PROCEDURE merge_employees()
BEGIN

    -- Delete rows that are already in the employee_dim table as it's pointless to merge them
    DELETE FROM staging WHERE MD5(CONCAT(
        employee_id, full_name, hire_date, job_id, salary, 
        COALESCE(commission_pct, ''), email, phone_number, COALESCE(manager_id, ''), COALESCE(department_id, '')
    )) IN (SELECT surrogate_employee_id FROM employee_dim WHERE is_current = TRUE);

    CREATE TABLE old_surrogate_id (surrogate_employee_id CHAR(32))
    SELECT surrogate_employee_id FROM employee_dim WHERE employee_id IN (SELECT employee_id from staging) AND is_current = TRUE;

    UPDATE employee_dim JOIN staging USING (employee_id)
    SET is_current = FALSE, effective_end_date = NOW() WHERE is_current = TRUE;
    
    INSERT INTO employee_dim (employee_id, full_name, hire_date, job_id, salary, commission_pct, email, phone_number, manager_id, department_id) 
    SELECT * FROM staging;

    UPDATE employee_yearly_salary_fact AS fact
    JOIN old_surrogate_id USING (surrogate_employee_id)
    JOIN employee_dim AS dim ON dim.employee_id IN (SELECT employee_id FROM staging) AND is_current = TRUE
    SET fact.surrogate_employee_id = dim.surrogate_employee_id;

    DROP TABLE old_surrogate_id;

END $$

DELIMITER ;

CALL merge_employees();
