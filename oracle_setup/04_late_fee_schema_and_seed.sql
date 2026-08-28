-- Run as: RCC_APP (same schema as pkg_rcc)

CREATE TABLE accounts (
  account_id      NUMBER PRIMARY KEY,
  hardship_flag   VARCHAR2(1) DEFAULT 'N' NOT NULL
);

-- 2001: normal account, standard fee path
INSERT INTO accounts VALUES (2001, 'N');
-- 2002: hardship flag -> fee waived
INSERT INTO accounts VALUES (2002, 'Y');
-- 2003 intentionally NOT inserted -> tests NO_DATA_FOUND / unknown account
COMMIT;

-- Deploy the function itself:
-- @"<path to>\sp_calc_late_fee.sql"

-- Manual test calls once deployed:
-- SELECT SP_CALC_LATE_FEE(2001, 3,   500) FROM dual; -- grace period -> 0
-- SELECT SP_CALC_LATE_FEE(2001, 10,  500) FROM dual; -- normal -> 25 (5% of 500=25, >=25 flat)
-- SELECT SP_CALC_LATE_FEE(2001, 10, 4000) FROM dual; -- capped -> 150
-- SELECT SP_CALC_LATE_FEE(2002, 10,  500) FROM dual; -- hardship -> 0
-- SELECT SP_CALC_LATE_FEE(2003, 10,  500) FROM dual; -- unknown account -> NULL
