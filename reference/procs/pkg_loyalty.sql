CREATE OR REPLACE PACKAGE PKG_LOYALTY AS

  PROCEDURE APPLY_LOYALTY_DISCOUNT(
    p_customer_id   IN NUMBER,
    p_order_id      IN NUMBER,
    p_order_amount  IN NUMBER,
    p_status_out    OUT VARCHAR2
  );

END PKG_LOYALTY;
/

CREATE OR REPLACE PACKAGE BODY PKG_LOYALTY AS

  PROCEDURE APPLY_LOYALTY_DISCOUNT(
    p_customer_id   IN NUMBER,
    p_order_id      IN NUMBER,
    p_order_amount  IN NUMBER,
    p_status_out    OUT VARCHAR2
  ) IS
    v_trailing_spend  NUMBER;
    v_discount_pct    NUMBER;
    v_discount_amt    NUMBER;
    v_lockout_count   NUMBER;
  BEGIN
    -- Business logic hidden in an aggregate query: trailing-12-month spend
    SELECT NVL(SUM(order_amount), 0)
    INTO   v_trailing_spend
    FROM   orders
    WHERE  customer_id = p_customer_id
    AND    order_dt >= ADD_MONTHS(SYSDATE, -12);

    -- Business logic hidden in a lookup: active promo lockout
    SELECT COUNT(*)
    INTO   v_lockout_count
    FROM   promo_lockout
    WHERE  customer_id = p_customer_id
    AND    SYSDATE BETWEEN lockout_start AND lockout_end;

    IF v_lockout_count > 0 THEN
      p_status_out := 'LOCKOUT_SKIPPED';
      INSERT INTO loyalty_discount_log
        (customer_id, order_id, order_amount, discount_pct, discount_amt, status)
      VALUES (p_customer_id, p_order_id, p_order_amount, 0, 0, p_status_out);
      COMMIT;
      RETURN;
    END IF;

    IF v_trailing_spend >= 5000 THEN
      v_discount_pct := 0.15;
    ELSIF v_trailing_spend >= 2000 THEN
      v_discount_pct := 0.10;
    ELSIF v_trailing_spend >= 500 THEN
      v_discount_pct := 0.05;
    ELSE
      v_discount_pct := 0;
    END IF;

    v_discount_amt := ROUND(p_order_amount * v_discount_pct, 2);

    UPDATE orders
    SET    discount_applied = v_discount_amt
    WHERE  order_id = p_order_id;

    p_status_out := 'OK';

    INSERT INTO loyalty_discount_log
      (customer_id, order_id, order_amount, discount_pct, discount_amt, status)
    VALUES (p_customer_id, p_order_id, p_order_amount, v_discount_pct, v_discount_amt, p_status_out);

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_status_out := 'ERROR: ' || SUBSTR(SQLERRM, 1, 200);
      INSERT INTO loyalty_discount_log
        (customer_id, order_id, order_amount, discount_pct, discount_amt, status)
      VALUES (p_customer_id, p_order_id, p_order_amount, NULL, NULL, p_status_out);
      COMMIT;
  END APPLY_LOYALTY_DISCOUNT;

END PKG_LOYALTY;
/
