CREATE OR REPLACE FUNCTION SP_CALC_LATE_FEE(
  p_account_id  IN NUMBER,
  p_days_late   IN NUMBER,
  p_balance     IN NUMBER
) RETURN NUMBER IS
  v_fee       NUMBER;
  v_hardship  VARCHAR2(1);
BEGIN
  SELECT hardship_flag INTO v_hardship
  FROM   accounts
  WHERE  account_id = p_account_id;

  IF p_days_late <= 5 THEN
    RETURN 0; -- grace period, no fee
  END IF;

  IF v_hardship = 'Y' THEN
    RETURN 0; -- hardship flag waives late fees entirely
  END IF;

  v_fee := GREATEST(25, ROUND(p_balance * 0.05, 2));

  IF v_fee > 150 THEN
    v_fee := 150; -- fee cap
  END IF;

  RETURN v_fee;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL; -- unknown account_id
END SP_CALC_LATE_FEE;
/
