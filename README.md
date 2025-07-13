# Oracle HR Database ETL Project

In this project I develop a simple ETL pipeline that extracts data similar to Oracle's HR database from the CSV files provided in `data/` into a MySQL database. Additionally, a simple API is available to interact with the database that enables currency conversion. The database's ERD diagram follows a star schema, with one fact table in the middle surrounded by dimension tables. The fact table contains a foreign key referring to each dimension's primary key. The resulting ERD is the following:

![](OracleERD.svg)

The fact table contains a row for each employee for each year since the year they have been hired.

## How to run the code yourself

### Option 1: Docker

The application can be run using docker by simply running

```bash
docker compose up
```

If ran for the first time, this will execute all scripts in the `sql/` directory in order inside a docker container and will store the database in the `oraclehr_etl_data` volume. The MySQL database will be mapped to the local port **3307** (To avoid conflicts with an already running instance of `mysql` on port **3306**) and the API will be mapped to local port **8000**. For details, check out the `docker-compose.yaml`. It's best to wait before the API service is ready.

### Option 2: Local

One can also run everything locally by first running

```bash
mysql --local-infile -u root -p
```

This will open mysql and attempt to log in as root. You will be prompted to type your root password. The `--local-infile` parameter is required for the first time to enable loading data from the local CSV files. In case this does not work, make sure that your local MySQL server is running using (on Linux):

```bash
systemctl status mysql
```

If it is inactive, start it using:

```bash
systemctl start mysql
```

Once inside, you can run the `run_all.sql` script that will run all scripts in the `sql/` directory as follows:

```bash
source run_all.sql
```

You can also run the script outside of `mysql` by doing this:

```bash
mysql --local-infile -u root -p < run_all.sql
```

But the output tables will not be formatted as nicely in the terminal.

After the database has been created, you need to first make sure that the environment variable `MYSQL_ROOT_PASSWORD` is set to your root password, as that will be used by the API to connect to the database. It can be set as follows:

```bash
export MYSQL_ROOT_PASSWORD=your_root_password
```

Then, you can run the API as follows:

```bash
pip install -r requirements.txt
fastapi run api.py
```

This will start the API on port **8000** by default. You can customize it by passing `--port` to the `fastapi` command. 

## Structure of the API

The API is quite minimal, it simply queries the fact table in Python using Pandas. It implements only `GET` requests, which can be done using `curl` as follows:

```bash
curl "http://localhost:8000/path/to/endpoint?query1=1&query2=2"
```

The implemented endpoints are:

1. All requested queries in the assignment description
    - `/total-compensation-by-region`: Retrieve the total compensation per region. Query parameters: `EUR` (boolean) - Set to `true` to convert all currencies to EUR.
    - `/total-compensation-per-employee-latest`: Retrieve the total compensation for each employee for the latest available calendar year. Query parameters: `EUR` (boolean) - Set to `true` to convert all currencies to EUR.
    - `/average-salary-per-job-category`: Retrieve the mean salary for each job category. This internally converts all currencies to EUR since there are jobs within the same job category but different regions (e.g. Management in EU and US). Query parameters: `year` (int) - retrieve the yearly salary for that year. By default, it is set to the latest available year.
    - `/employees-changed-departments`: Retrieve all employees that changed departments (i.e., were hired in the predefined range). Query parameteres: `from_year` (int), `to_year` (int) - Set the range of years. Defaults to (2005, 2018).
    - `/top-paid-per-department`: Retrieve the most paid employees for each department. Query parameters: `EUR` (boolean) - Set to `true` to convert all currencies to EUR. `top` (int) - Set the number of employees to retrieve for each department, defaults to 5.
2. Specific information about individual employees, departments, and years
    - `/employees/{employee_id}`: Retrieve information for the given employee id (e.g. 101, 102, 103, etc.). Query parameters: `EUR` (boolean) - Set to `true` to convert all currencies to EUR. `year` (int) - retrieve information about a given year. Defaults to the latest available year.
    - `/years/{year}`: Retrieve information for the state of the company at a given year (e.g. 2023, 2022, etc.) including employees and departments. Query parameters: `EUR` (boolean) - Set to `true` to convert all currencies to EUR.
    - `/departments/{department_id}`: Retrieve information for a specific department id (e.g. 10, 50, 80, etc.) including location and working employees. Query parameters: `EUR` (boolean) - Set to `true` to convert all currencies to EUR. `year` (int) - retrieve information about a given year. Defaults to the latest available year.
