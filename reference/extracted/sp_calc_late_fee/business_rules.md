# Business Rules — SP_CALC_LATE_FEE

Source: `reference/procs/sp_calc_late_fee.sql`
Derived from: `reference/extracted/sp_calc_late_fee/structural_inventory.md`

One rule per branch / exception handler identified in the structural
inventory (3 `IF` branches + 1 exception handler = 4 rules). The grace
period check and the hardship check are kept as separate rules even
though both return a $0 fee — they trigger on different, independent
conditions and must be testable independently.

**BR-03 is now a confirmed rule that intentionally differs from the
deployed source — see its section below.** Everything else in this
file reflects what the deployed function actually does.

---

## BR-01 — Grace period

**Quoted source (lines 13-15):**
```
IF p_days_late <= 5 THEN
    RETURN 0; -- grace period, no fee
END IF;
```

**Plain-English testable rule:**
If the number of days a payment is late is 5 or fewer, the late fee is
$0 — regardless of account balance and regardless of hardship status.

**Confidence:** Explicit (inline comment "grace period, no fee" directly
states the rule's intent).

---

## BR-02 — Hardship waiver

**Quoted source (lines 17-19):**
```
IF v_hardship = 'Y' THEN
    RETURN 0; -- hardship flag waives late fees entirely
END IF;
```

**Plain-English testable rule:**
For an account more than 5 days late (BR-01 did not apply), if that
account's `hardship_flag` is `'Y'`, the late fee is $0 — regardless of
balance.

**Confidence:** Explicit (inline comment "hardship flag waives late
fees entirely" directly states the rule's intent).

---

## BR-03 — Standard fee amount (confirmed; intentionally diverges from deployed source)

**Quoted source (lines 21-25) — what the deployed proc still does:**
```
v_fee := GREATEST(25, ROUND(p_balance * 0.05, 2));

IF v_fee > 150 THEN
    v_fee := 150; -- fee cap
END IF;
```
As written, this computes the greater of $25 or 5% of the outstanding
balance, capped at $150. **This is now known to be an outdated
implementation** — the confirmed rule below supersedes it, and the
deployed `SP_CALC_LATE_FEE` proc has not been (and per this pipeline's
scope, is not being) updated to match.

**Plain-English testable rule (confirmed):**
For an account more than 5 days late and without the hardship flag set
(BR-01 and BR-02 did not apply), the late fee is **$10 per day late,
uncapped**. `p_balance` plays no role in this rule at all.

**Confidence:** Confirmed by direct instruction from the project owner
in the Claude Code session on 2026-08-26. This is **not** the same as
the formal `business_owner_signoff` sign-off recorded in
`config/proc_inventory.yaml` (still `null`) or a decision recorded in
`DECISIONS.md`'s sign-off-authority section (still unset) — those
remain outstanding, separate governance steps. This entry records what
was directed and implemented, not a substitute for that formal record.

**Resolution of the open questions previously logged here:**
- **Accrual mechanism:** `$10 * p_days_late`, computed fresh from the
  `p_days_late` input on every call. No internal state — the fee grows
  over real-world time only because a caller is expected to re-invoke
  this with a larger `p_days_late` as more days pass.
- **Cap:** none. Confirmed uncapped — a payment 100 days late is a
  $1,000 fee, with no ceiling analogous to the old $150 cap.
- **Is the deployed source simply outdated?** Yes, per this direction —
  the $25-floor/5%-of-balance/$150-cap logic is a superseded
  calculation. The deployed PL/SQL proc has not been changed to match;
  `SP_CALC_LATE_FEE`'s live output for this branch is now expected to
  diverge from the C# implementation. See
  `reference/parity-fixtures/sp_calc_late_fee_actual_outputs.md` for
  where this is documented as a known, intentional divergence rather
  than a defect.

---

## BR-04 — Unknown account

**Quoted source (lines 29-31):**
```
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL; -- unknown account_id
```

**Plain-English testable rule:**
If `p_account_id` does not match any row in `accounts`, the function
returns `NULL` — not `0`, and not an error/exception raised to the
caller.

**Confidence:** Explicit (inline comment "unknown account_id" directly
states what condition this handles; the choice of `NULL` over `0` or a
raised error is explicit in the code, though *why* `NULL` was chosen
over the alternatives is not stated anywhere and is not asserted here).

---

## Summary

| Rule | Trigger condition | Result | Confidence |
|---|---|---|---|
| BR-01 | `p_days_late <= 5` | Fee = 0 | Explicit |
| BR-02 | `p_days_late > 5` AND `hardship_flag = 'Y'` | Fee = 0 | Explicit |
| BR-03 | `p_days_late > 5` AND `hardship_flag <> 'Y'` | Fee = `$10 * p_days_late`, uncapped, balance-independent — **deployed proc still computes `MIN(150, MAX(25, ROUND(balance * 0.05, 2)))` and has not been updated** | Confirmed 2026-08-26 (in-session direction; formal business_owner_signoff still outstanding) |
| BR-04 | `p_account_id` not found in `accounts` | Fee = `NULL` | Explicit |
