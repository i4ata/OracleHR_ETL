\! echo "Running merge_staging_tables.sql. Merge the staging tables and verify SCD2 integrity"

CALL merge_employees();
CALL merge_departments();
CALL merge_jobs();
CALL merge_locations();

