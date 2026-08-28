-- Run as: sqlplus RCC_APP/<your_password>@localhost:1521/XEPDB1 @03_seed_test_data.sql
-- Customer IDs are grouped by scenario so they're traceable back to
-- acceptance_criteria.md rule IDs once you write it in Step 6.

-- 1001: GOLD tier, joined after 2018 -> 20% cap applies, normal path
INSERT INTO customer_billing VALUES
  (1001, 100.00, 'GOLD', DATE '2020-03-15', DATE '2026-08-31', 'N', NULL, NULL);

-- 1002: SILVER tier, joined after 2018 -> 12% cap applies
INSERT INTO customer_billing VALUES
  (1002, 100.00, 'SILVER', DATE '2021-06-01', DATE '2026-08-31', 'N', NULL, NULL);

-- 1003: BRONZE/other tier, joined after 2018 -> 8% cap applies
INSERT INTO customer_billing VALUES
  (1003, 100.00, 'BRONZE', DATE '2022-01-10', DATE '2026-08-31', 'N', NULL, NULL);

-- 1004: joined before 2018 -> 5% cap overrides tier (GOLD but pre-2018)
INSERT INTO customer_billing VALUES
  (1004, 100.00, 'GOLD', DATE '2016-05-01', DATE '2026-08-31', 'N', NULL, NULL);

-- 1005: locked account -> should be skipped entirely
INSERT INTO customer_billing VALUES
  (1005, 100.00, 'GOLD', DATE '2019-01-01', DATE '2026-08-31', 'Y', NULL, NULL);

-- 1006: rate increase requested exactly AT the cap threshold (GOLD, 20% exactly)
INSERT INTO customer_billing VALUES
  (1006, 100.00, 'GOLD', DATE '2020-01-01', DATE '2026-08-31', 'N', NULL, NULL);

-- 1007: zero-day proration window -- effective date lands ON the cycle end
INSERT INTO customer_billing VALUES
  (1007, 100.00, 'GOLD', DATE '2020-01-01', DATE '2026-08-26', 'N', NULL, NULL);

-- 1008: for the "prorated amount itself gets capped at 115% of new rate" case
-- (large old->new rate jump early in the cycle)
INSERT INTO customer_billing VALUES
  (1008, 10.00, 'GOLD', DATE '2020-01-01', DATE '2026-08-31', 'N', NULL, NULL);

-- Note: customer_id 9999 is intentionally NOT inserted -> used to test NOT_FOUND

COMMIT;

-- Batch idempotency test data: two customers queued for the same batch date
INSERT INTO rate_change_queue VALUES (1001, 115.00, DATE '2026-08-26', 'N', NULL);
INSERT INTO rate_change_queue VALUES (1002, 108.00, DATE '2026-08-26', 'N', NULL);

COMMIT;

-- After running APPLY_RATE_CHANGE / RUN_BATCH_RATE_CHANGE manually per the
-- Claude Code prompt in the guide, re-run this SELECT to capture actual
-- results as your parity fixture:
-- SELECT * FROM rate_change_log ORDER BY log_id;
-- SELECT * FROM customer_billing ORDER BY customer_id;
