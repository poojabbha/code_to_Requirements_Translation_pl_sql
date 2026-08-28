-- Run as: sqlplus SYSTEM/<your_password>@localhost:1521/XEPDB1 @01_create_app_user.sql
-- Creates a dedicated schema for this pipeline demo instead of using SYSTEM.
--
-- Prompts for the new RCC_APP password at run time (input hidden, not
-- echoed) so no credential is ever stored in this file or in git history.

SET VERIFY OFF
ACCEPT app_password CHAR PROMPT 'Enter password for new RCC_APP user: ' HIDE

CREATE USER RCC_APP IDENTIFIED BY "&app_password"
  DEFAULT TABLESPACE USERS
  QUOTA UNLIMITED ON USERS;

UNDEFINE app_password

GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE VIEW TO RCC_APP;

-- Sanity check
SELECT username, account_status FROM dba_users WHERE username = 'RCC_APP';
