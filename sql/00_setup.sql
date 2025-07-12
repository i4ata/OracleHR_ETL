\! echo '------------------------------------------------------------------------------'
\! echo 'Running setup.sql. WARNING: Reinitializing the database, everything is deleted'
\! echo '------------------------------------------------------------------------------'

DROP DATABASE IF EXISTS OLAP;
CREATE DATABASE OLAP;
USE OLAP;
