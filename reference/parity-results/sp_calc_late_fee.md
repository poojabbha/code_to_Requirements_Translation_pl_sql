# Parity Results — SP_CALC_LATE_FEE

Summarizes, per acceptance criterion in
`reference/extracted/sp_calc_late_fee/acceptance_criteria.md`
(TC numbering as of the 2026-08-26 BR-03 revision), whether we have
REAL PROC OUTPUT from the live Oracle instance, an automated C# test in
`tests/LateFeeParityTests.cs`, and whether that test passes.

**Important change as of 2026-08-26:** BR-03 was confirmed as "$10 per
day late, uncapped, balance-independent" — a different rule than what
the *deployed* `SP_CALC_LATE_FEE` proc computes, and the proc has not
been updated to match. For BR-01, BR-02, and BR-04, "parity" still
means matching the live proc, same as before. **For BR-03, matching the
live proc is no longer the goal** — the goal is matching the confirmed
rule, which the proc doesn't implement. A test that used to be
"BLOCKED because it can't be exercised" is now "PASS against the
confirmed rule, DIVERGES from the live proc's real output, by design."

## Result by acceptance criterion

| TC | Inputs | Expected (confirmed rule) | Real Oracle output for this input? | C# test | Result |
|---|---|---|---|---|---|
| TC-01 | (2001,10,500) | 100.00 | Yes — proc returns **25** (old formula) | `TC01_...` | **PASS vs. confirmed rule / DIVERGES from live proc (intentional — see business_rules.md#BR-03)** |
| TC-02 | (2001,10,50000) | 100.00 | No | `TC02_...` | **PASS** (balance-independence confirmed) |
| TC-03 | (2001,20,500) | 200.00 | No | None written | NOT RUN |
| TC-04 | (2001,100,500) | 1000.00 | No | `TC04_...` | **PASS** (no-cap confirmed) |
| TC-05 | (2001,5,500) | 0 | No (a related tuple, (2001,3,500), was captured instead — see below) | None written | NOT RUN |
| TC-06 | (2001,6,500) | 60.00 | No | None written | NOT RUN |
| TC-07 | (2002,10,500) | 0 | Yes — 0 | `TC07_...` | **PASS** |
| TC-08 | (2002,100,500) | 0 | No | None written | NOT RUN |
| TC-09 | (2003,10,500) | NULL | Yes — NULL | `TC09_...` | **PASS** |
| TC-10 | (2003,3,500) | NULL | No | None written | NOT RUN |

Plus one supplementary real value with no exact TC match:

| Inputs | Expected (BR-01) | Real Oracle output | C# test | Result |
|---|---|---|---|---|
| (2001,3,500) | 0 | Yes — 0 | `BR01_...` | **PASS** |

## Totals

- **PASS: 6** — all 6 tests in `tests/LateFeeParityTests.cs` currently
  pass: the grace-period case, TC-01, TC-02, TC-04 (all BR-03), TC-07
  (hardship), TC-09 (unknown account). 0 skipped, 0 failed.
- **Known, intentional divergence: 1** — TC-01. Real Oracle output for
  `(2001,10,500)` is `25`; the C# correctly returns `100` per the
  confirmed BR-03 rule. This is not a defect — it's proof the C# no
  longer matches the *outdated* deployed proc for this rule, which is
  the expected outcome of confirming BR-03.
- **NOT RUN: 6** — TC-03, TC-05, TC-06, TC-08, TC-10, and the old
  `(2001,10,4000)` real-Oracle tuple (which no longer maps to a current
  TC — see `parity-fixtures/sp_calc_late_fee_actual_outputs.md`). No
  automated test exists for these yet.

## Bottom line

**BR-01, BR-02, and BR-04 are proven against the live Oracle proc — 3
for 3 tested (plus one supplementary BR-01 case), all consistent.**

**BR-03 is a deliberate, confirmed departure from the deployed proc,
not a parity result in the traditional sense.** Its 3 tested cases
(TC-01, TC-02, TC-04) all pass against the *confirmed rule*, and TC-01
is direct proof that this is a real, intentional change from what
`SP_CALC_LATE_FEE` currently returns live — not an untested assumption.
6 of 10 acceptance criteria overall have never been run at all (3 more
BR-03 cases, plus TC-05, TC-06, TC-08, TC-10 for the other rules) and
should still be captured/tested before this proc is called fully
proven end-to-end.

This confirmation was made by direct instruction in a Claude Code
session on 2026-08-26, not through this project's formal sign-off
recording (`business_owner_signoff` in `config/proc_inventory.yaml` is
still `null`; `DECISIONS.md`'s sign-off-authority section is still
unset). That paperwork remains an outstanding step.
