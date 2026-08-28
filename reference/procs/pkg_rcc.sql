CREATE OR REPLACE PACKAGE PKG_RCC AS

  g_max_run_date DATE := NULL;

  PROCEDURE APPLY_RATE_CHANGE(
    p_customer_id   IN NUMBER,
    p_effective_dt  IN DATE,
    p_new_rate      IN NUMBER,
    p_status_out    OUT VARCHAR2
  );

  FUNCTION CALC_PRORATED_AMT(
    p_old_rate   IN NUMBER,
    p_new_rate   IN NUMBER,
    p_eff_dt     IN DATE,
    p_cycle_end  IN DATE
  ) RETURN NUMBER;

  PROCEDURE RUN_BATCH_RATE_CHANGE(p_batch_dt IN DATE);

END PKG_RCC;
/

CREATE OR REPLACE PACKAGE BODY PKG_RCC AS

  FUNCTION CALC_PRORATED_AMT(
    p_old_rate   IN NUMBER,
    p_new_rate   IN NUMBER,
    p_eff_dt     IN DATE,
    p_cycle_end  IN DATE
  ) RETURN NUMBER IS
    v_days_total   NUMBER;
    v_days_old     NUMBER;
    v_days_new     NUMBER;
    v_amt          NUMBER;
  BEGIN
    v_days_total := p_cycle_end - TRUNC(p_eff_dt, 'MM');
    v_days_old   := p_eff_dt - TRUNC(p_eff_dt, 'MM');
    v_days_new   := v_days_total - v_days_old;

    IF v_days_total = 0 THEN
      RETURN p_new_rate;
    END IF;

    v_amt := ROUND(
               (p_old_rate / v_days_total) * v_days_old +
               (p_new_rate / v_days_total) * v_days_new,
               2
             );

    IF v_amt > (p_new_rate * 1.15) THEN
      v_amt := p_new_rate * 1.15;
    END IF;

    RETURN v_amt;
  END CALC_PRORATED_AMT;


  PROCEDURE APPLY_RATE_CHANGE(
    p_customer_id   IN NUMBER,
    p_effective_dt  IN DATE,
    p_new_rate      IN NUMBER,
    p_status_out    OUT VARCHAR2
  ) IS
    v_old_rate       NUMBER;
    v_tier           VARCHAR2(10);
    v_join_dt        DATE;
    v_cycle_end      DATE;
    v_prorated       NUMBER;
    v_locked         VARCHAR2(1);
    v_max_increase   NUMBER;

    CURSOR c_cust IS
      SELECT current_rate, cust_tier, join_date, billing_cycle_end, account_locked
      FROM   customer_billing
      WHERE  customer_id = p_customer_id
      FOR UPDATE;

  BEGIN
    OPEN c_cust;
    FETCH c_cust INTO v_old_rate, v_tier, v_join_dt, v_cycle_end, v_locked;

    IF c_cust%NOTFOUND THEN
      CLOSE c_cust;
      p_status_out := 'NOT_FOUND';
      RETURN;
    END IF;

    IF v_locked = 'Y' THEN
      CLOSE c_cust;
      p_status_out := 'SKIPPED_LOCKED';
      RETURN;
    END IF;

    IF v_join_dt < DATE '2018-01-01' THEN
      v_max_increase := 0.05;
    ELSIF v_tier = 'GOLD' THEN
      v_max_increase := 0.20;
    ELSIF v_tier = 'SILVER' THEN
      v_max_increase := 0.12;
    ELSE
      v_max_increase := 0.08;
    END IF;

    IF (p_new_rate - v_old_rate) / NVL(v_old_rate, 1) > v_max_increase THEN
      DBMS_OUTPUT.PUT_LINE('Capping rate increase for customer ' || p_customer_id);
      p_status_out := 'CAPPED';
    ELSE
      p_status_out := 'OK';
    END IF;

    v_prorated := CALC_PRORATED_AMT(v_old_rate, p_new_rate, p_effective_dt, v_cycle_end);

    UPDATE customer_billing
    SET    current_rate = p_new_rate,
           last_rate_change_dt = p_effective_dt,
           last_prorated_amt = v_prorated
    WHERE  customer_id = p_customer_id;

    INSERT INTO rate_change_log (customer_id, old_rate, new_rate, effective_dt, prorated_amt, status)
    VALUES (p_customer_id, v_old_rate, p_new_rate, p_effective_dt, v_prorated, p_status_out);

    CLOSE c_cust;

    IF p_status_out = 'OK' THEN
      COMMIT;
    ELSE
      COMMIT;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IF c_cust%ISOPEN THEN
        CLOSE c_cust;
      END IF;
      ROLLBACK;
      p_status_out := 'ERROR: ' || SUBSTR(SQLERRM, 1, 200);
      INSERT INTO rate_change_log (customer_id, old_rate, new_rate, effective_dt, prorated_amt, status)
      VALUES (p_customer_id, v_old_rate, p_new_rate, p_effective_dt, NULL, p_status_out);
      COMMIT;
  END APPLY_RATE_CHANGE;


  PROCEDURE RUN_BATCH_RATE_CHANGE(p_batch_dt IN DATE) IS
    v_status VARCHAR2(200);
    CURSOR c_pending IS
      SELECT customer_id, proposed_rate
      FROM   rate_change_queue
      WHERE  scheduled_dt <= p_batch_dt
      AND    processed_flag = 'N';
  BEGIN
    IF g_max_run_date IS NOT NULL AND p_batch_dt <= g_max_run_date THEN
      RAISE_APPLICATION_ERROR(-20001, 'Batch already run for this or a later date');
    END IF;

    FOR r IN c_pending LOOP
      APPLY_RATE_CHANGE(r.customer_id, p_batch_dt, r.proposed_rate, v_status);

      UPDATE rate_change_queue
      SET    processed_flag = 'Y',
             processed_dt = SYSDATE
      WHERE  customer_id = r.customer_id
      AND    proposed_rate = r.proposed_rate;
    END LOOP;

    g_max_run_date := p_batch_dt;
    COMMIT;
  END RUN_BATCH_RATE_CHANGE;

END PKG_RCC;
/
