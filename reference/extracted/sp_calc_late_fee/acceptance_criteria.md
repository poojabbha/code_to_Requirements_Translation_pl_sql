# Acceptance Criteria — SP_CALC_LATE_FEE

Numbered test cases derived from `requirements.md` and
`technical_spec.md`. Seed data (`oracle_setup/04_late_fee_schema_and_seed.sql`)
already provides everything these cases need: account `2001`
(`hardship_flag = 'N'`), account `2002` (`hardship_flag = 'Y'`), and no
account `2003` (used for the unknown-account cases).

**Revision note (2026-08-26):** BR-03 was confirmed as "$10 per day
late, uncapped, balance-independent," replacing the deployed proc's
floor/percentage/cap formula. That removed `p_balance` as a variable in
BR-03 entirely, which made the previous TC-01 through TC-07 (all built
around flat-vs-percentage and cap *boundaries in balance*) test a
concept that no longer exists. Those seven cases have been replaced
with four cases relevant to the confirmed rule (normal case,
balance-independence, linearity across day counts, and no-cap at a
large day count). TC IDs below are renumbered sequentially as a result
— they do **not** match the TC numbers used in earlier versions of this
file or in already-written references to old TC-03/TC-07.

**BR-03 no longer means "matches the deployed proc."** For TC-01
through TC-04 below, the *deployed* `SP_CALC_LATE_FEE` would return a
different value than the "Expected result" column (since the proc
still runs the old formula) — that's expected and intentional, not a
defect. See `reference/parity-fixtures/sp_calc_late_fee_actual_outputs.md`
for where the one overlapping real-Oracle data point is reconciled.

## Test cases

| TC | Inputs `(account_id, days_late, balance)` | Expected result | Rule(s) | Why this case |
|---|---|---|---|---|
| TC-01 | `(2001, 10, 500)` | `100.00` | BR-03 | Normal case: `10 * 10 = 100`. Note: real Oracle output for this exact tuple was captured as `25` under the old formula — this is the one point where the confirmed rule and the deployed proc's real output are known to disagree; see the parity-fixtures note. |
| TC-02 | `(2001, 10, 50000)` | `100.00` | BR-03 | Balance independence: identical result to TC-01 despite a wildly different balance, confirming `p_balance` no longer affects the fee at all. |
| TC-03 | `(2001, 20, 500)` | `200.00` | BR-03 | Linearity: doubling `days_late` (10 → 20) doubles the fee (`10 * 20 = 200`), confirming the fee scales linearly with days late. |
| TC-04 | `(2001, 100, 500)` | `1000.00` | BR-03 | No cap: a very large day count (100) produces a correspondingly large fee (`10 * 100 = 1000`) with no ceiling — this would have been clamped to `150` under the old (deployed) formula. |
| TC-05 | `(2001, 5, 500)` | `0` | BR-01 | Grace period boundary, exactly 5 days late: `p_days_late <= 5` is true (`5 <= 5`), so the grace period applies and no fee is charged. |
| TC-06 | `(2001, 6, 500)` | `60.00` | BR-01, BR-03 | Grace period boundary, 6 days late: `p_days_late <= 5` is now false, so this is the first day the fee calculation actually runs (`10 * 6 = 60`). |
| TC-07 | `(2002, 10, 500)` | `0` | BR-02 | Hardship flag waives the fee for an otherwise-normal, non-grace-period case. |
| TC-08 | `(2002, 100, 500)` | `0` | BR-02 | Hardship flag waives the fee even at a day count large enough that, without hardship, the fee would be substantial (`$1000` per TC-04's rate) — confirms hardship overrides regardless of magnitude, now that magnitude is driven by days late instead of balance. |
| TC-09 | `(2003, 10, 500)` | `NULL` | BR-04 | Unknown account: no row in `accounts` matches `account_id = 2003`, so `NO_DATA_FOUND` fires and the function returns `NULL` (previously verified live). |
| TC-10 | `(2003, 3, 500)` | `NULL` | BR-04 | Unknown account takes precedence over the grace period: even though `p_days_late <= 5` would otherwise return `0` (BR-01), the account lookup (step 1 in `technical_spec.md`'s control flow) runs *first* and fails before BR-01 is ever evaluated. Confirms the ordering, not just the outcome. |

## Rule ID coverage

| Rule | Covered by |
|---|---|
| BR-01 (grace period) | TC-05, TC-06 |
| BR-02 (hardship waiver) | TC-07, TC-08 |
| BR-03 (standard fee amount — confirmed, diverges from deployed proc) | TC-01 through TC-04, TC-06 |
| BR-04 (unknown account) | TC-09, TC-10 |

Every rule from `business_rules.md` is exercised by at least one test
case; BR-01, BR-02, and BR-04 are each exercised by two, to cover both
the boundary/normal value and an ordering or magnitude edge case.
