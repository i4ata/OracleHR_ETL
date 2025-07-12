CREATE TABLE staging 
SELECT employee_id, full_name, hire_date, job_id, salary, commission_pct, email, phone_number, manager_id, department_id 
FROM employee_dim WHERE employee_id = 101;

UPDATE staging SET commission_pct = 0.1;

DELIMITER $$

CREATE PROCEDURE merge_employees()
BEGIN
    UPDATE employee_dim as dim, staging
    SET dim.is_current = FALSE, dim.effective_end_date = NOW()
    WHERE  dim.employee_id = staging.employee_id;

    INSERT INTO employee_dim (
        employee_id,
        full_name,
        hire_date,
        job_id,
        salary,
        commission_pct,
        email,
        phone_number,
        manager_id,
        department_id
    ) SELECT * FROM staging;

END $$

DELIMITER ;

CALL merge_employees();
