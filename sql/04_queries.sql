\! echo "Running queries.sql. Run 5 queries on the database"

-- ---------------------------- --
-- Total compensation by region --
-- ---------------------------- --
SELECT region_name, COALESCE(SUM(total_compensation), 0) AS total_compensation
FROM employee_yearly_salary_fact RIGHT JOIN location_dim USING (surrogate_location_id)
GROUP BY region_name ORDER BY total_compensation DESC;

-- --------------------------------------------------- --
-- Total compensation per employee for the latest year --
-- --------------------------------------------------- --
SELECT year, employee_id, full_name, job_title, job_category, department_id, department_name, region_name, total_compensation
FROM employee_yearly_salary_fact 
JOIN (SELECT * FROM time_dim WHERE year = (SELECT MAX(year) FROM time_dim)) AS latest_year USING (surrogate_time_id)
JOIN (SELECT surrogate_employee_id, employee_id, full_name FROM employee_dim) AS employees USING (surrogate_employee_id)
JOIN job_dim USING (surrogate_job_id)
JOIN department_dim USING (surrogate_department_id)
JOIN location_dim USING (surrogate_location_id)
ORDER BY total_compensation DESC;

-- ------------------------------- --
-- Average salary per job category --
-- ------------------------------- --
SELECT job_category, AVG(salary) AS average_yearly_salary
FROM employee_yearly_salary_fact
JOIN job_dim USING (surrogate_job_id)
GROUP BY job_category ORDER BY average_yearly_salary DESC;

-- --------------------------------------------------- --
-- Employees who changed departments between 2005-2018 --
-- --------------------------------------------------- --
SELECT DISTINCT(employee_id), full_name
FROM employee_yearly_salary_fact
JOIN employee_dim USING (surrogate_employee_id)
JOIN department_dim USING (surrogate_department_id)
WHERE YEAR(hire_date) BETWEEN 2005 AND 2018;

-- ----------------------------------------------- --
-- Top 5 highest-paid employees in each department -- for the latest year
-- ----------------------------------------------- --
WITH ranked_salaries AS (
    SELECT employee_id, full_name, job_title, job_category, department_id, department_name, region_name, salary, RANK() OVER(PARTITION BY department_id ORDER BY salary DESC) AS salary_rank
    FROM employee_yearly_salary_fact
    JOIN (SELECT * FROM time_dim WHERE year = (SELECT MAX(year) FROM time_dim)) AS latest_year USING (surrogate_time_id)
    JOIN (SELECT surrogate_employee_id, employee_id, full_name FROM employee_dim) AS employees USING (surrogate_employee_id)
    JOIN job_dim USING (surrogate_job_id)
    JOIN department_dim USING (surrogate_department_id)
    JOIN location_dim USING (surrogate_location_id)
)
SELECT * FROM ranked_salaries WHERE salary_rank <= 5;
