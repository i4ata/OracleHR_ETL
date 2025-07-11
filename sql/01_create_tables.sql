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
    location_id DECIMAL(4,0) UNIQUE NOT NULL,
    street_address VARCHAR(40),
    postal_code VARCHAR(12),
    city VARCHAR(30),
    state_province VARCHAR(25),
    country_id CHAR(2),
    country_name VARCHAR(52),
    region_id DECIMAL,
    region_name VARCHAR(25),

    PRIMARY KEY (surrogate_location_id)
);

CREATE TABLE job_dim (
    surrogate_job_id CHAR(32),
    job_id VARCHAR(10) UNIQUE NOT NULL,
    job_title VARCHAR(35),
    min_salary DECIMAL(6,0),
    max_salary DECIMAL(6,0),
    job_category VARCHAR(30),
    
    CONSTRAINT job_category_valid CHECK (job_category in ('Management', 'Technical/Professional', 'Clerical/Support', 'Other')),
    PRIMARY KEY (surrogate_job_id)
);

CREATE TABLE employee_dim (
    surrogate_employee_id CHAR(32),
    employee_id DECIMAL(6,0) UNIQUE NOT NULL,
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
    
    CONSTRAINT tenure_band_valid CHECK (tenure_band IN ('Less than 1 year', '1-3 years', '4-6 years', '7-10 years', '10+ years')),
    CONSTRAINT email_valid CHECK (email LIKE '%@egt.com'),
    CONSTRAINT phone_number_valid CHECK (phone_number LIKE '+359%'),
    PRIMARY KEY (surrogate_employee_id),
    FOREIGN KEY (job_id) REFERENCES job_dim(job_id)
);

CREATE TABLE department_dim (
    surrogate_department_id CHAR(32),
    department_id DECIMAL(6,0) UNIQUE NOT NULL,
    department_name VARCHAR(30),
    location_id DECIMAL(4,0),
    manager_id DECIMAL(6,0),
    
    PRIMARY KEY (surrogate_department_id),
    FOREIGN KEY (location_id) REFERENCES location_dim(location_id) ON UPDATE CASCADE
);

ALTER TABLE employee_dim ADD FOREIGN KEY (department_id) REFERENCES department_dim(department_id);

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
    effective_date DATE,

    PRIMARY KEY (surrogate_fact_id),
    FOREIGN KEY (surrogate_employee_id) REFERENCES employee_dim(surrogate_employee_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_department_id) REFERENCES department_dim(surrogate_department_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_job_id) REFERENCES job_dim(surrogate_job_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_time_id) REFERENCES time_dim(surrogate_time_id) ON UPDATE CASCADE,
    FOREIGN KEY (surrogate_location_id) REFERENCES location_dim(surrogate_location_id) ON UPDATE CASCADE
);
