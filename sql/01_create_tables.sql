CREATE TABLE employee_dim (
    surrogate_employee_id CHAR(32),
    employee_id DECIMAL(6,0) NOT NULL,
    full_name VARCHAR(41),
    hire_date DATE,
    job_id VARCHAR(10),
    salary DECIMAL(8,2),
    commission_pct DECIMAL(2,2) DEFAULT 0,
    email VARCHAR(33),
    phone_number VARCHAR(20),
    manager_id DECIMAL(6,0),
    department_id DECIMAL(4,0),
    tenure_band VARCHAR(20),

    effective_start_date TIMESTAMP DEFAULT NOW(),
    effective_end_date TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT tenure_band_valid CHECK (tenure_band IN ('Less than 1 year', '1-3 years', '4-6 years', '7-10 years', '10+ years')),
    CONSTRAINT email_valid CHECK (email LIKE '%@egt.com'),
    CONSTRAINT phone_number_valid CHECK (phone_number LIKE '+359%'),
    PRIMARY KEY (surrogate_employee_id)
);

DELIMITER $$

CREATE TRIGGER before_insert_employee BEFORE INSERT ON employee_dim
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_employee_id = MD5(CONCAT(
            NEW.employee_id, NEW.full_name, NEW.hire_date, NEW.job_id, NEW.salary, 
            COALESCE(NEW.commission_pct, ''), NEW.email, NEW.phone_number, COALESCE(NEW.manager_id, ''), COALESCE(NEW.department_id, '')
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

DELIMITER ;

CREATE TABLE department_dim (
    surrogate_department_id CHAR(32),
    department_id DECIMAL(6,0) NOT NULL,
    department_name VARCHAR(30),
    location_id DECIMAL(4,0),
    manager_id DECIMAL(6,0),

    effective_start_date TIMESTAMP DEFAULT NOW(),
    effective_end_date TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,
    
    PRIMARY KEY (surrogate_department_id)
);

DELIMITER $$

CREATE TRIGGER before_insert_department BEFORE INSERT ON department_dim
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_department_id = MD5(CONCAT(
            NEW.department_id, NEW.department_name, NEW.location_id, COALESCE(NEW.manager_id, '')
        ));
    END $$

DELIMITER ;

CREATE TABLE job_dim (
    surrogate_job_id CHAR(32),
    job_id VARCHAR(10) NOT NULL,
    job_title VARCHAR(35),
    min_salary DECIMAL(6,0),
    max_salary DECIMAL(6,0),
    job_category VARCHAR(30),

    effective_start_date TIMESTAMP DEFAULT NOW(),
    effective_end_date TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,    
    
    CONSTRAINT job_category_valid CHECK (job_category in ('Management', 'Technical/Professional', 'Clerical/Support', 'Other')),
    PRIMARY KEY (surrogate_job_id)
);

DELIMITER $$

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

DELIMITER ;

CREATE TABLE time_dim (
    surrogate_time_id CHAR(32),
    time_id CHAR(8) NOT NULL,
    dates DATE,
    year DECIMAL(4,0),
    quarter DECIMAL(1,0),
    month DECIMAL(2,0),
    week DECIMAL(2,0),
    day DECIMAL(2,0),
    day_of_week VARCHAR(10),
    fiscal_year DECIMAL(4,0),
    fiscal_quarter DECIMAL(1,0),

    PRIMARY KEY(surrogate_time_id)
);

CREATE TABLE location_dim (
    surrogate_location_id CHAR(32),
    location_id DECIMAL(4,0) NOT NULL,
    street_address VARCHAR(40),
    postal_code VARCHAR(12),
    city VARCHAR(30),
    state_province VARCHAR(25),
    country_id CHAR(2),
    country_name VARCHAR(52),
    region_id DECIMAL,
    region_name VARCHAR(25),

    effective_start_date TIMESTAMP DEFAULT NOW(),
    effective_end_date TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,    

    PRIMARY KEY (surrogate_location_id)
);

DELIMITER $$

CREATE TRIGGER before_insert_location BEFORE INSERT ON location_dim
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_location_id = MD5(CONCAT(
            NEW.location_id, NEW.street_address, NEW.postal_code, NEW.city, NEW.state_province, NEW.country_id, NEW.country_name, NEW.region_id, NEW.region_name
        ));
    END $$

DELIMITER ;


CREATE TABLE employee_yearly_salary_fact (
    surrogate_fact_id CHAR(32),
    surrogate_employee_id CHAR(32),
    surrogate_department_id CHAR(32),
    surrogate_job_id CHAR(32),
    surrogate_time_id CHAR(32),
    surrogate_location_id CHAR(32),
    salary DECIMAL(9,2),
    bonus DECIMAL(9,2),
    total_compensation DECIMAL(9,2),
    effective_date TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (surrogate_fact_id),
    FOREIGN KEY (surrogate_employee_id) REFERENCES employee_dim(surrogate_employee_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_department_id) REFERENCES department_dim(surrogate_department_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_job_id) REFERENCES job_dim(surrogate_job_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_time_id) REFERENCES time_dim(surrogate_time_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_location_id) REFERENCES location_dim(surrogate_location_id) ON UPDATE CASCADE
);

DELIMITER $$

CREATE TRIGGER before_insert_fact BEFORE INSERT ON employee_yearly_salary_fact
    FOR EACH ROW
    BEGIN
        SET NEW.surrogate_fact_id = MD5(CONCAT(
            NEW.surrogate_employee_id, NEW.surrogate_department_id, NEW.surrogate_job_id, NEW.surrogate_time_id, NEW.surrogate_location_id, NEW.salary
        ));
        SET NEW.salary = 12 * NEW.salary;
        SET @commission_pct = (SELECT commission_pct FROM employee_dim WHERE surrogate_employee_id = NEW.surrogate_employee_id AND is_current = 1);
        SET NEW.bonus = NEW.salary * @commission_pct;
        SET NEW.total_compensation = NEW.salary + NEW.bonus;
    END $$

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
