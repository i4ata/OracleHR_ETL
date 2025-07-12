\! echo '--------------------------------------------------------------------------'
\! echo 'Running create_triggers.sql. Create triggers for inserting into the tables'
\! echo '--------------------------------------------------------------------------'

-- The dimension triggers are used to automatically fill in columns that are directly derived from other columns
-- This is always true for the surrogate id, which is md5 applied to the whole row

DELIMITER $$

-- ---------------- --
-- INSERT EMPLOYEES --
-- ---------------- --
CREATE TRIGGER before_insert_employee BEFORE INSERT ON employee_dim
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_employee_id = MD5(CONCAT(
            NEW.employee_id, NEW.full_name, NEW.hire_date, NEW.job_id, NEW.salary, 
            COALESCE(NEW.commission_pct, ''), NEW.email, NEW.phone_number, COALESCE(NEW.manager_id, ''), COALESCE(NEW.department_id, ''),
            NEW.effective_start_date
        ));
        SET @tenure_years = TIMESTAMPDIFF(YEAR, NEW.hire_date, CURDATE());
        SET NEW.tenure_band = CASE 
            WHEN @tenure_years < 1              THEN 'Less than 1 year'
            WHEN @tenure_years BETWEEN 1 and 3  THEN '1-3 years'
            WHEN @tenure_years BETWEEN 4 and 6  THEN '4-6 years'
            WHEN @tenure_years BETWEEN 7 and 10 THEN '7-10 years'
            WHEN @tenure_years > 10             THEN '10+ years'
            ELSE NULL
        END;
    END $$

-- ------------------ --
-- INSERT DEPARTMENTS --
-- ------------------ --
CREATE TRIGGER before_insert_department BEFORE INSERT ON department_dim
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_department_id = MD5(CONCAT(
            NEW.department_id, NEW.department_name, NEW.location_id, COALESCE(NEW.manager_id, ''), NEW.effective_start_date
        ));
    END $$

-- ----------- --
-- INSERT JOBS --
-- ----------- --
CREATE TRIGGER before_insert_job BEFORE INSERT ON job_dim
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_job_id = MD5(CONCAT(
            NEW.job_id, NEW.job_title, NEW.min_salary, NEW.max_salary
        ));
        SET NEW.job_category = CASE
            WHEN NEW.job_title LIKE '%President%'  OR NEW.job_title LIKE '%Manager%'                                                THEN 'Management'
            WHEN NEW.job_title LIKE '%Programmer%' OR NEW.job_title LIKE '%Accountant%' OR NEW.job_title LIKE '%Representative%'    THEN 'Technical/Professional'
            WHEN NEW.job_title LIKE '%Assistant%'  OR NEW.job_title LIKE '%Clerk%'                                                  THEN 'Clerical/Support'
                                                                                                                                    ELSE 'Other'
        END;
    END $$

-- ---------------- --
-- INSERT LOCATIONS --
-- ---------------- --
CREATE TRIGGER before_insert_location BEFORE INSERT ON location_dim
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_location_id = MD5(CONCAT(
            NEW.location_id, NEW.street_address, NEW.postal_code, NEW.city, NEW.state_province, NEW.country_id, 
            NEW.country_name, NEW.region_id, NEW.region_name, NEW.effective_start_date
        ));
    END $$


-- ------------ --
-- INSERT FACTS --
-- ------------ --
CREATE TRIGGER before_insert_fact BEFORE INSERT ON employee_yearly_salary_fact
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_fact_id = MD5(CONCAT(
            NEW.surrogate_employee_id, NEW.surrogate_department_id, NEW.surrogate_job_id, 
            NEW.surrogate_time_id, NEW.surrogate_location_id, NEW.salary, NEW.effective_date
        ));
        SET NEW.salary = 12 * NEW.salary;
        SET @commission_pct = (SELECT commission_pct FROM employee_dim WHERE surrogate_employee_id = NEW.surrogate_employee_id AND is_current = 1);
        SET NEW.bonus = NEW.salary * @commission_pct;
        SET NEW.total_compensation = NEW.salary + NEW.bonus;
    END $$

-- ------------ --
-- UPDATE FACTS --
-- ------------ --
-- Update the compensation columns when a surrogate_employee_id has been updated. This is applied in the scd2 merging
CREATE TRIGGER update_compensation BEFORE UPDATE ON employee_yearly_salary_fact
    FOR EACH ROW
    BEGIN
        IF NEW.surrogate_employee_id <> OLD.surrogate_employee_id THEN
        
            SELECT salary, commission_pct INTO @new_salary, @new_commission_pct FROM employee_dim 
            WHERE surrogate_employee_id = NEW.surrogate_employee_id AND is_current = 1;
            
            -- Sucks a bit that the lines are mostly repeated from the trigger above
            SET NEW.salary = 12 * @new_salary;
            SET @commission_pct = @new_commission_pct;
            SET NEW.bonus = NEW.salary * @commission_pct;
            SET NEW.total_compensation = NEW.salary + NEW.bonus;
        END IF;
    END $$

DELIMITER ;

\! echo 'All triggers created successfully'
