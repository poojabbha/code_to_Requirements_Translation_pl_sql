-- Run as: sqlplus RCC_APP/<your_password>@localhost:1521/XEPDB1 @02_create_schema.sql

CREATE TABLE customer_billing (
  customer_id         NUMBER PRIMARY KEY,
  current_rate         NUMBER(10,2) NOT NULL,
  cust_tier            VARCHAR2(10) NOT NULL,      -- GOLD | SILVER | other
  join_date            DATE NOT NULL,
  billing_cycle_end    DATE NOT NULL,
  account_locked       VARCHAR2(1) DEFAULT 'N' NOT NULL,
  last_rate_change_dt  DATE,
  last_prorated_amt    NUMBER(10,2)
);

CREATE SEQUENCE rate_change_log_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE rate_change_log (
  log_id        NUMBER PRIMARY KEY,
  customer_id   NUMBER NOT NULL,
  old_rate      NUMBER(10,2),
  new_rate      NUMBER(10,2),
  effective_dt  DATE,
  prorated_amt  NUMBER(10,2),
  status        VARCHAR2(200),
  logged_at     DATE DEFAULT SYSDATE
);

CREATE TABLE rate_change_queue (
  customer_id     NUMBER NOT NULL,
  proposed_rate   NUMBER(10,2) NOT NULL,
  scheduled_dt    DATE NOT NULL,
  processed_flag  VARCHAR2(1) DEFAULT 'N' NOT NULL,
  processed_dt    DATE
);

CREATE OR REPLACE TRIGGER rate_change_log_bi
BEFORE INSERT ON rate_change_log
FOR EACH ROW
WHEN (NEW.log_id IS NULL)
BEGIN
  SELECT rate_change_log_seq.NEXTVAL INTO :NEW.log_id FROM dual;
END;
/
-- pkg_rcc.sql's INSERT INTO rate_change_log doesn't specify log_id, so this
-- trigger fills it in — needed because the package body wasn't written with
-- an explicit ID strategy (worth flagging as a gap in the technical spec).

-- After this runs, deploy the package itself:
-- sqlplus RCC_APP/<your_password>@localhost:1521/XEPDB1 @reference/procs/pkg_rcc.sql
