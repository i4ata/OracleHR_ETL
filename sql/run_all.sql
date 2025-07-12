\! echo "Run all scripts in the ./sql directory in order"

source sql/00_setup.sql
source sql/01_create_tables.sql
source sql/02_create_triggers.sql
source sql/03_populate_tables.sql
source sql/04_queries.sql
source sql/scd2/05_create_staging_tables.sql
source sql/scd2/06_create_merging_procedures.sql
source sql/scd2/07_merge_staging_tables.sql
