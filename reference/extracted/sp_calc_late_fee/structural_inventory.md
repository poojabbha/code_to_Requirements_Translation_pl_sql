# Structural Inventory — SP_CALC_LATE_FEE

Source: `reference/procs/sp_calc_late_fee.sql` (33 lines)

This is a structural inventory only. No business interpretation of *why*
any rule exists — that belongs in a separate business-rules pass.

## Signature

```
FUNCTION SP_CALC_LATE_FEE(
  p_account_id  IN NUMBER,
  p_days_late   IN NUMBER,
  p_balance     IN NUMBER
) RETURN NUMBER
```

- Line 1-5
- 3 IN parameters, no OUT/IN OUT parameters
- Return type: NUMBER (also the type used for NULL return on the exception path — see Exception Handler below)

## Local variables

| Name | Type | Declared | Line |
|---|---|---|---|
| `v_fee` | `NUMBER` | Line 6 |
| `v_hardship` | `VARCHAR2(1)` | Line 7 |

## Tables referenced

| Table | Operation | Line(s) | Columns read | Predicate |
|---|---|---|---|---|
| `accounts` | `SELECT ... INTO` | 9-11 | `hardship_flag` (→ `v_hardship`) | `account_id = p_account_id` |

Only one table access in the entire function body: a single-row lookup
by primary key (`account_id`) into a scalar variable. No `UPDATE`,
`INSERT`, `DELETE`, cursor, or joins. No other tables referenced.

## Branch points (in execution order)

| # | Line(s) | Construct | Condition | Action on TRUE | Falls through to |
|---|---|---|---|---|---|
| 1 | 13-15 | `IF ... THEN ... END IF;` | `p_days_late <= 5` | `RETURN 0;` (line 14) | Branch 2 (line 17) |
| 2 | 17-19 | `IF ... THEN ... END IF;` | `v_hardship = 'Y'` | `RETURN 0;` (line 18) | Line 21 (assignment) |
| 3 | 23-25 | `IF ... THEN ... END IF;` | `v_fee > 150` | `v_fee := 150;` (line 24) | Line 27 (`RETURN v_fee;`) |

All three are simple `IF` blocks with no `ELSE`/`ELSIF` clauses. Branches
1 and 2 are early-return guards; branch 3 clamps `v_fee` in place and
execution continues to the return on line 27.

## Non-branching computation

| Line | Statement |
|---|---|
| 21 | `v_fee := GREATEST(25, ROUND(p_balance * 0.05, 2));` |

Single assignment, evaluated only if execution reaches line 21 (i.e.,
neither branch 1 nor branch 2 returned early). Uses two built-in
functions: `ROUND(..., 2)` and `GREATEST(25, ...)`.

## Return points

| Line | Value | Reached when |
|---|---|---|
| 14 | `0` | Branch 1 condition true |
| 18 | `0` | Branch 1 false, branch 2 condition true |
| 27 | `v_fee` (post branch-3 clamp, if applied) | Branch 1 and branch 2 both false |
| 31 | `NULL` | Exception handler fires (see below) |

4 distinct `RETURN` statements total — 3 in the main body, 1 in the
exception handler.

## Exception handler

| Line(s) | Construct |
|---|---|
| 29-31 | `EXCEPTION WHEN NO_DATA_FOUND THEN RETURN NULL;` |

- Single exception handler for the entire function body (`EXCEPTION`
  section starts line 29, function ends line 32).
- Handles exactly one named exception: `NO_DATA_FOUND`.
- `NO_DATA_FOUND` can only originate from the `SELECT ... INTO` on lines
  9-11 (the sole query in the function) when zero rows match
  `account_id = p_account_id`.
- No `WHEN OTHERS` clause — any exception other than `NO_DATA_FOUND`
  (e.g., `TOO_MANY_ROWS`, though not possible here since `account_id` is
  the primary key) is not caught by this function and propagates to the
  caller.

## Comments present in source (verbatim, not interpreted)

| Line | Comment |
|---|---|
| 14 | `-- grace period, no fee` |
| 18 | `-- hardship flag waives late fees entirely` |
| 24 | `-- fee cap` |
| 31 | `-- unknown account_id` |

## Control flow summary (structure only)

```
SELECT hardship_flag INTO v_hardship FROM accounts WHERE account_id = p_account_id
  │
  ├─ NO_DATA_FOUND ──────────────────────────────────► RETURN NULL  (line 31)
  │
  ▼
IF p_days_late <= 5 ────────────────────true─────────► RETURN 0    (line 14)
  │ false
  ▼
IF v_hardship = 'Y' ────────────────────true─────────► RETURN 0    (line 18)
  │ false
  ▼
v_fee := GREATEST(25, ROUND(p_balance * 0.05, 2))     (line 21)
  │
  ▼
IF v_fee > 150 ─────true──► v_fee := 150 (line 24) ──┐
  │ false                                             │
  └─────────────────────────────────────────────────► RETURN v_fee (line 27)
```
