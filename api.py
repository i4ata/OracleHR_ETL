from fastapi import FastAPI
from typing import Optional, List
from sqlalchemy import create_engine
import pandas as pd
import os

app = FastAPI()
engine = create_engine('mysql+pymysql://root:4e7LyYzF@localhost/OLAP')
with open(os.path.join('sql', '03_queries.sql')) as f: queries = f.read().split('\n\n')

to_eur = {
    'Americas': 0.86,
    'Europe': 1.,
    'Asia': 0.12,
    'Oceania': 0.56,
    'Afrika': 0.048 # Maybe you mean Africa?
}

currencies = {
    'Americas' : 'USD',
    'Europe': 'EUR',
    'Asia': 'CNY',
    'Oceania': 'AUD',
    'Afrika': 'ZAR'
}

def employee_info_query(employee_id: int, year: Optional[int]) -> str:
    return f"""
    SELECT year, employee_id, full_name, job_title, job_category, country_name, region_name, department_name, employee_yearly_salary_fact.salary as yearly_salary, bonus, total_compensation
    FROM employee_yearly_salary_fact
    JOIN (SELECT surrogate_employee_id, employee_id, full_name FROM employee_dim where employee_id = {employee_id}) AS employee USING (surrogate_employee_id)
    JOIN (SELECT surrogate_time_id, year FROM time_dim WHERE year = {year if year is not None else '(SELECT MAX(year) FROM time_dim) AS time'}) AS time USING (surrogate_time_id)
    JOIN job_dim USING (surrogate_job_id)
    JOIN department_dim USING (surrogate_department_id)
    JOIN location_dim USING (surrogate_location_id)
    """

def convert(df: pd.DataFrame, currency_columns: List[str], EUR: bool) -> pd.DataFrame:
    assert 'region_name' in df.columns
    assert set(currency_columns).issubset(df.columns)
    if EUR:
        df[currency_columns] = df[currency_columns].multiply(df['region_name'].map(to_eur), axis='index')
        df['currency'] = 'EUR'
    else:
        df['currency'] = df['region_name'].map(currencies)
    return df

@app.get('/employees/{employee_id}')
def employee_info(employee_id: int, year: Optional[int] = None, EUR: bool = False):
    query: pd.DataFrame = pd.read_sql_query(employee_info_query(employee_id, year), con=engine)
    query = convert(query, ['yearly_salary', 'bonus', 'total_compensation'], EUR)
    return query.to_dict('records')

@app.get('/total-compensation-by-region')
def q0(EUR: bool = False):
    query: pd.DataFrame = pd.read_sql_query(queries[0], con=engine)
    query = convert(query, ['total_compensation'], EUR)
    return query.to_dict('records')

@app.get('/total-compensation-per-employee-latest')
def q1(EUR: bool = False):
    query: pd.DataFrame = pd.read_sql_query(queries[1], con=engine)
    query = convert(query, ['total_compensation'], EUR)
    return query.to_dict('records')

@app.get('/average-salary-per-job-category')
def q2(year: Optional[int] = None):
    query_str = f"""
    SELECT job_category, salary, region_name
    FROM employee_yearly_salary_fact
    JOIN (SELECT * FROM time_dim WHERE year = {year if year is not None else '(SELECT MAX(year) FROM time_dim)'}) AS time USING (surrogate_time_id)
    JOIN job_dim USING (surrogate_job_id)
    JOIN location_dim USING (surrogate_location_id)    
    """
    query: pd.DataFrame = pd.read_sql_query(query_str, con=engine)
    query = convert(query, ['salary'], True)
    query = query.groupby('job_category', as_index=False)['salary'].mean().round(2)
    return query.to_dict('records')

@app.get('/employees-changed-departments')
def q3(from_year: int = 2005, to_year: int = 2018):
    if from_year > to_year: from_year, to_year = to_year, from_year
    query: pd.DataFrame = pd.read_sql_query(queries[3].replace('2005', str(from_year)).replace('2018', str(to_year)), con=engine)
    return query.to_dict('records')

@app.get('/top-paid-per-department')
def q4(EUR: bool = False, top: int = 5):
    query: pd.DataFrame = pd.read_sql_query(queries[4].replace('5', str(top)), con=engine)
    query = convert(query, ['salary'], EUR)
    return query.to_dict('records')
