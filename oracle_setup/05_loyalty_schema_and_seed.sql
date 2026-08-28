-- Run as: RCC_APP (same schema as pkg_rcc)

CREATE TABLE orders (
  order_id           NUMBER PRIMARY KEY,
  customer_id        NUMBER NOT NULL,
  order_amount       NUMBER(10,2) NOT NULL,
  order_dt           DATE NOT NULL,
  discount_applied   NUMBER(10,2)
);

CREATE TABLE promo_lockout (
  customer_id     NUMBER NOT NULL,
  lockout_start   DATE NOT NULL,
  lockout_end     DATE NOT NULL
);

CREATE SEQUENCE loyalty_log_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE loyalty_discount_log (
  log_id          NUMBER PRIMARY KEY,
  customer_id     NUMBER,
  order_id        NUMBER,
  order_amount    NUMBER(10,2),
  discount_pct    NUMBER(4,2),
  discount_amt    NUMBER(10,2),
  status          VARCHAR2(200),
  logged_at       DATE DEFAULT SYSDATE
);

CREATE OR REPLACE TRIGGER loyalty_discount_log_bi
BEFORE INSERT ON loyalty_discount_log
FOR EACH ROW
WHEN (NEW.log_id IS NULL)
BEGIN
  SELECT loyalty_log_seq.NEXTVAL INTO :NEW.log_id FROM dual;
END;
/

-- Seed data by scenario:

-- 3001: trailing spend >= 5000 -> PLATINUM 15%
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9001, 3001, 6000, ADD_MONTHS(SYSDATE, -2));
-- 3002: trailing spend >= 2000, < 5000 -> GOLD 10%
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9002, 3002, 2500, ADD_MONTHS(SYSDATE, -3));
-- 3003: trailing spend >= 500, < 2000 -> SILVER 5%
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9003, 3003, 800, ADD_MONTHS(SYSDATE, -1));
-- 3004: trailing spend < 500 -> no discount
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9004, 3004, 100, ADD_MONTHS(SYSDATE, -1));
-- 3005: would qualify for PLATINUM but is in an active lockout window
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9005, 3005, 6000, ADD_MONTHS(SYSDATE, -1));
INSERT INTO promo_lockout VALUES (3005, SYSDATE - 5, SYSDATE + 5);

-- The new order each customer is actually placing right now (the p_order_id
-- passed into the proc call below) -- separate row per customer, current amount
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9101, 3001, 300, SYSDATE);
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9102, 3002, 300, SYSDATE);
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9103, 3003, 300, SYSDATE);
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9104, 3004, 300, SYSDATE);
INSERT INTO orders (order_id, customer_id, order_amount, order_dt) VALUES (9105, 3005, 300, SYSDATE);

COMMIT;

-- Deploy the package itself:
-- @"<path to>\pkg_loyalty.sql"

-- Manual test calls once deployed:
-- DECLARE v_status VARCHAR2(200); BEGIN
--   PKG_LOYALTY.APPLY_LOYALTY_DISCOUNT(3001, 9101, 300, v_status); DBMS_OUTPUT.PUT_LINE(v_status);
--   PKG_LOYALTY.APPLY_LOYALTY_DISCOUNT(3002, 9102, 300, v_status); DBMS_OUTPUT.PUT_LINE(v_status);
--   PKG_LOYALTY.APPLY_LOYALTY_DISCOUNT(3003, 9103, 300, v_status); DBMS_OUTPUT.PUT_LINE(v_status);
--   PKG_LOYALTY.APPLY_LOYALTY_DISCOUNT(3004, 9104, 300, v_status); DBMS_OUTPUT.PUT_LINE(v_status);
--   PKG_LOYALTY.APPLY_LOYALTY_DISCOUNT(3005, 9105, 300, v_status); DBMS_OUTPUT.PUT_LINE(v_status);
-- END;
-- /
-- SELECT * FROM loyalty_discount_log ORDER BY log_id;
