# Technical Spec — SP_CALC_LATE_FEE

Audience: developers implementing the C# equivalent and anyone writing
parity tests. Based on `structural_inventory.md` and
`business_rules.md` in this same folder; table DDL cross-referenced
from `oracle_setup/04_late_fee_schema_and_seed.sql` since neither input
document contains the full table definition.

**BR-03 (the standard fee amount) is confirmed as $10/day, uncapped,
balance-independent — see Control Flow, Step 4. This intentionally no
longer matches the deployed PL/SQL proc, which still runs the old
floor/percentage/cap formula and has not been updated; see
business_rules.md#BR-03 for the record of that decision.**

## Function signature and return contract

```
FUNCTION SP_CALC_LATE_FEE(
  p_account_id  IN NUMBER,
  p_days_late   IN NUMBER,
  p_balance     IN NUMBER
) RETURN NUMBER
```

| Parameter | Type | Direction | Contract |
|---|---|---|---|
| `p_account_id` | `NUMBER` | IN | Required. Looked up as `accounts.account_id` (primary key). No validation of sign or magnitude in the function itself. |
| `p_days_late` | `NUMBER` | IN | Required. Number of days the payment is overdue. No validation; negative or fractional values are not rejected and flow into the `<= 5` comparison as-is. |
| `p_balance` | `NUMBER` | IN | Required by the signature, but **no longer used in the confirmed BR-03 calculation** (the $10/day rule is balance-independent). Still present because it's part of the original PL/SQL signature. No validation; not checked for negative values. |

**Return type:** `NUMBER`. There are exactly four possible return values
/ value classes, corresponding to the four rules in `business_rules.md`:

| Return value | Condition | Rule |
|---|---|---|
| `0` | `p_days_late <= 5` | BR-01 |
| `0` | `p_days_late > 5` and `hardship_flag = 'Y'` | BR-02 |
| `10 * p_days_late`, uncapped (deployed proc instead still computes `MIN(150, MAX(25, ROUND(balance * 0.05, 2)))` — outdated, unchanged) | `p_days_late > 5` and `hardship_flag <> 'Y'` | BR-03 — **confirmed; C# intentionally diverges from the live proc** |
| `NULL` | `p_account_id` does not match any row in `accounts` | BR-04 |

**NULL-for-unknown-account is a deliberate, explicit contract, not an
absence of a value.** A caller cannot distinguish "$0 fee" from
"unknown account" by checking for falsy/zero — it must explicitly check
for `NULL`. Any C# port must preserve this as a three-state return
(a computed decimal, `0`, or an explicit "no value" — e.g. `decimal?`
returning `null`), not collapse it to `0` or throw.

**Side effects:** none. The function performs a single read-only
`SELECT`, has no `OUT`/`IN OUT` parameters, and issues no `INSERT`,
`UPDATE`, `DELETE`, `COMMIT`, or `ROLLBACK`. It is safe to call multiple
times with the same inputs and get the same result (pure function
given the same table state).

## Data contract — `accounts` table

Per `oracle_setup/04_late_fee_schema_and_seed.sql`:

```sql
CREATE TABLE accounts (
  account_id      NUMBER PRIMARY KEY,
  hardship_flag   VARCHAR2(1) DEFAULT 'N' NOT NULL
);
```

| Column | Type | Constraint | Used by this function as |
|---|---|---|---|
| `account_id` | `NUMBER` | Primary key | Lookup key, matched against `p_account_id` |
| `hardship_flag` | `VARCHAR2(1)` | `NOT NULL`, default `'N'` | Read into `v_hardship`, compared to `'Y'` |

- Access pattern: `SELECT hardship_flag INTO v_hardship FROM accounts WHERE account_id = p_account_id` — a single-row lookup by primary key. Because `account_id` is the primary key, this can return at most one row; `TOO_MANY_ROWS` is not reachable given the current schema.
- `hardship_flag` is constrained `NOT NULL` at the schema level, so the function's `v_hardship = 'Y'` check never has to handle a `NULL` flag under the current schema. **Porting note:** if the target SQL Server/Oracle table backing the C# implementation ever relaxes this constraint, a `NULL` flag would evaluate as "not hardship" under Oracle's three-valued logic (`NULL = 'Y'` is unknown, so the `IF` is false) — the C# equivalent (`hardshipFlag == "Y"`) preserves this automatically since a `null` string is also `!= "Y"` in C#, but this equivalence should be tested explicitly rather than assumed if the constraint ever changes.
- No other tables are referenced.
- **Verified porting pitfall:** Oracle folds unquoted DDL identifiers to
  uppercase, so the table created as `accounts` is actually stored as
  `ACCOUNTS`. EF Core's Oracle provider quotes identifiers exactly as
  configured in `HasColumnName`/`ToTable`, so a lowercase `"accounts"`
  mapping is a different, case-sensitive, nonexistent object and fails
  with `ORA-00942: table or view does not exist`. Confirmed live while
  standing up `src/RccMigration.Api` — the fix is mapping to `ACCOUNTS`
  / `ACCOUNT_ID` / `HARDSHIP_FLAG` (uppercase) in
  `LateFeeDbContext.cs`.

## Control flow

Preconditions: none enforced by the function itself (see parameter contract above — no input validation).

1. **Account lookup.** `SELECT hardship_flag INTO v_hardship FROM accounts WHERE account_id = p_account_id`.
   - No row found → jump directly to the exception handler → return `NULL` (BR-04). Steps 2-5 below never execute.
2. **Grace period check (BR-01).** If `p_days_late <= 5`, return `0`. Stop.
3. **Hardship check (BR-02).** If `v_hardship = 'Y'`, return `0`. Stop.
4. **Standard fee amount (BR-03 — confirmed).** `v_fee := 10 * p_days_late`. No floor, no percentage-of-balance, no cap — `p_balance` is not read at all in this step.
   - This intentionally supersedes what the *deployed* proc still computes (`GREATEST(25, ROUND(p_balance * 0.05, 2))`, capped at `150`) — the proc has not been updated to match and is not in scope for this pipeline to change. See `business_rules.md#BR-03` for the record of this decision. A C# implementation of this step should now produce `10 * daysLate` and must not attempt to reproduce the deployed proc's old formula.
5. **Return.** Return `v_fee`.

```
account lookup
  ├─ not found ──────────────────────► return NULL   [BR-04]
  ▼
days_late <= 5? ──yes───────────────► return 0        [BR-01]
  │ no
  ▼
hardship_flag = 'Y'? ──yes──────────► return 0        [BR-02]
  │ no
  ▼
fee = 10 * days_late ───────────────► return fee       [BR-03 — confirmed, no cap]
```

## Exception-handling contract

| Exception | Handled? | Behavior |
|---|---|---|
| `NO_DATA_FOUND` | Yes | Caught; function returns `NULL` instead of propagating. This is the *only* handled exception. |
| Any other exception (e.g. a future `TOO_MANY_ROWS` if the schema ever changed, numeric/value errors from malformed inputs, etc.) | No — no `WHEN OTHERS` clause | Propagates uncaught to the caller. The function does not swallow, log, or wrap any exception other than `NO_DATA_FOUND`. |

**Porting implication:** the C# equivalent must catch only the
"record not found" case and translate it to a `null`/`NULL` return.
Every other error condition must be allowed to surface as a real
exception (or whatever the target codebase's standard error-handling
convention is) rather than being caught and suppressed — silently
returning `null`/`0` for an unrelated error would not be behaviorally
equivalent to the original function.

There is no transaction control (`COMMIT`/`ROLLBACK`) anywhere in the
function, so there is no compensating cleanup logic to preserve in the
exception path.
