# REAL PROC OUTPUT — SP_CALC_LATE_FEE

Captured 2026-08-26. Run directly against the live Oracle instance
(RCC_APP schema) — not computed, not inferred. This is the actual
authoritative parity baseline for the five inputs below, as opposed to
the expected values in `acceptance_criteria.md`, most of which are
derived by hand from the source and have not (yet) all been
independently confirmed against the live database.

| # | Inputs `(account_id, days_late, balance)` | REAL PROC OUTPUT | Matching `acceptance_criteria.md` TC (post 2026-08-26 renumbering) |
|---|---|---|---|
| 1 | `(2001, 10, 500)` | `25` | TC-01 (expected value there is now `100`, not `25` — see note below) |
| 2 | `(2001, 3, 500)` | `0` | none exactly — exercises BR-01 (grace period); TC-05 tests the boundary at `days_late = 5`, this input uses `days_late = 3` |
| 3 | `(2002, 10, 500)` | `0` | TC-07 |
| 4 | `(2001, 10, 4000)` | `150` | none exactly — the old balance-driven cap case was replaced; TC-02/TC-04 now cover balance-independence and no-cap with different inputs |
| 5 | `(2003, 10, 500)` | `NULL` | TC-09 |

## Note on rows 1 and 4 (BR-03) — known, intentional divergence

BR-03 (the standard fee amount) was originally the greater of $25 or 5%
of balance, capped at $150 — rows 1 and 4 above are real, live-captured
proof of that formula's actual output on 2026-08-26.

**As of 2026-08-26, BR-03 was confirmed to be a different rule: $10 per
day late, uncapped, independent of balance** (see
`reference/extracted/sp_calc_late_fee/business_rules.md#BR-03`).
`src/RccMigration/LateFee/LateFeeCalculator.cs` now implements *that*
rule. The deployed `SP_CALC_LATE_FEE` proc has **not** been updated to
match and is not in scope for this pipeline to change — so these two
real values are retained here as the historical, accurate record of
what the *legacy proc* does, not as the target the C# is trying to
reproduce. For `(2001, 10, 500)`: the proc returns `25`; the C#
(correctly, per the confirmed rule) returns `100`. That mismatch is
expected and is not a parity bug — see
`reference/parity-results/sp_calc_late_fee.md` for how this is scored.

`tests/LateFeeParityTests.cs` asserts the C# side against the
*confirmed rule's* values (e.g. `100`, not `25`), with a comment at
each such test explaining the intentional divergence from what's in
this file.
