# AI Journal — PL/SQL to C# Business Logic Extraction

## Entries

### 2026-08-26 — SP_CALC_LATE_FEE — Structural inventory (pre-business-rules pass)

**Prompt (or summary of what I asked):**

"Read reference/procs/sp_calc_late_fee.sql in full. Do not interpret
business meaning yet. Produce a structural inventory: the function
signature, every table referenced and how, every branch point with
line numbers, and the exception handler. Save as
reference/extracted/sp_calc_late_fee/structural_inventory.md"

**What Claude Code did / proposed:**

Read the full 33-line source and wrote
reference/extracted/sp_calc_late_fee/structural_inventory.md containing:
the function signature and parameter list; the single table access
(`accounts`, `SELECT ... INTO` by `account_id`, no other tables/DML);
all 3 `IF` branch points with line numbers and literal conditions; the
4 return points (0, 0, v_fee, NULL); the single exception handler
(`WHEN NO_DATA_FOUND` only, no `WHEN OTHERS`); the verbatim source
comments; and a control-flow diagram. No business interpretation was
added, per the instruction.

**Did I accept it as-is, correct it, or reject it? Why:**

Accepted as-is — no corrections requested.

**Outcome:**

structural_inventory.md committed to
reference/extracted/sp_calc_late_fee/. Next step is a separate
business-rules interpretation pass before generating any C# code or
seeking sign-off.

---

### 2026-08-26 — SP_CALC_LATE_FEE — Business rules extraction, BR-03 divergence flagged

**Prompt (or summary of what I asked):**

"Using reference/extracted/sp_calc_late_fee/structural_inventory.md and
the source file, extract one business rule per branch/exception
handler: Rule ID, exact quoted snippet with line numbers, plain-English
testable rule, Confidence (Explicit/Inferred). Don't merge the grace
period check and the hardship check into one rule even though both
result in a zero fee. Save as
reference/extracted/sp_calc_late_fee/business_rules.md"

**What Claude Code did / proposed:**

First draft mapped BR-01 (grace period, days_late <= 5 -> $0), BR-02
(hardship flag 'Y' -> $0), BR-03 (standard fee = GREATEST($25, 5% of
balance), capped at $150 — matching source lines 21-25 exactly), and
BR-04 (NO_DATA_FOUND -> NULL for unknown account). Rejected before
saving: BR-03 should instead be "$10 per day until they submit fee" — a
rule that does not exist anywhere in the current source. Claude Code
flagged the mismatch and asked whether business_rules.md should (a)
document the code as-is plus a discrepancy note, (b) state the $10/day
rule as the intended behavior on the understanding the source may be
outdated/wrong, or (c) something else.

**Did I accept it as-is, correct it, or reject it? Why:**

Corrected — chose option (b): write BR-03 as the $10/day rule, on the
basis that this is the real intended business rule and the deployed
source may not (yet) implement it.

**Outcome:**

business_rules.md saved with BR-01, BR-02, BR-04 reflecting actual
source behavior (Confidence: Explicit). BR-03 is documented as a
flagged divergence: states the $10/day rule as directed, quotes what
the code currently computes instead, lists open questions (no "until
paid" state available to a single stateless function call, no stated
cap, unclear whether the source is simply outdated), and is marked
blocked from driving any C# generation or parity-test expected values
until a business/domain owner resolves the conflict per CLAUDE.md's
sign-off requirement.

---

### 2026-08-26 — SP_CALC_LATE_FEE — Plain-language requirements

**Prompt (or summary of what I asked):**

"Using business_rules.md, write
reference/extracted/sp_calc_late_fee/requirements.md for a
non-technical audience: purpose, trigger, and each rule in plain
language. Flag any 'Inferred' rules as open questions."

**What Claude Code did / proposed:**

Wrote requirements.md with a plain-language purpose statement, trigger
description, and all 4 rules restated without code/line references.
BR-03 isn't literally labeled "Inferred" in business_rules.md (it's
"N/A — diverges from source, unsigned-off"), but Claude Code flagged it
as an open question anyway since it's the most uncertain rule of the
four, listing 3 specific open questions (which formula is correct,
whether there's a cap, how "days late" is meant to be tracked). BR-01,
BR-02, BR-04 were noted as having no open questions.

**Did I accept it as-is, correct it, or reject it? Why:**

Accepted as-is — no corrections requested.

**Outcome:**

requirements.md saved to reference/extracted/sp_calc_late_fee/.

---

### 2026-08-26 — SP_CALC_LATE_FEE — Technical spec

**Prompt (or summary of what I asked):**

"Using structural_inventory.md and business_rules.md, write
reference/extracted/sp_calc_late_fee/technical_spec.md: function
signature and return contract (including the NULL-for-unknown-account
behavior), data contract for the accounts table, control flow, and the
exception-handling contract."

**What Claude Code did / proposed:**

Wrote technical_spec.md. Pulled the actual `accounts` table DDL from
oracle_setup/04_late_fee_schema_and_seed.sql (not just the `SELECT`
usage documented in structural_inventory.md) to give a complete data
contract, including a porting note on Oracle three-valued-logic vs. C#
null comparison for `hardship_flag`. Documented the return contract as
4 outcomes (0, 0, computed fee, NULL), the control flow as an ordered
step list plus diagram, and the exception-handling contract (only
`NO_DATA_FOUND` caught, everything else must propagate uncaught in the
C# port). BR-03 flagged as unresolved throughout, with an explicit
statement that generating C# for that step would mean guessing at an
unconfirmed contract.

**Did I accept it as-is, correct it, or reject it? Why:**

Accepted as-is — no corrections requested.

**Outcome:**

technical_spec.md saved to reference/extracted/sp_calc_late_fee/. The
BR-03 "don't guess" language here becomes the basis for later stubbing
it in the generated C# code.

---

### 2026-08-26 — SP_CALC_LATE_FEE — Acceptance criteria

**Prompt (or summary of what I asked):**

"Using requirements.md and technical_spec.md, write
reference/extracted/sp_calc_late_fee/acceptance_criteria.md as
numbered test cases: normal fee, fee at the flat-vs-percentage
boundary, fee capped at 150, grace period (exactly 5 days and 6 days),
hardship flag, and unknown account. Map every Rule ID to at least one
test case."

**What Claude Code did / proposed:**

Wrote 13 numbered test cases (TC-01–TC-13) covering all 6 requested
categories, plus 2 extra edge cases that fell out of the control flow
(cap-boundary branch coverage at TC-05/TC-06, and an
unknown-account-precedes-grace-period ordering case at TC-13). Every
Rule ID (BR-01–BR-04) mapped to at least one test case; BR-01 and BR-04
each get two. Every BR-03-tagged case carries the same "current-code,
not signed-off" caveat as business_rules.md.

**Did I accept it as-is, correct it, or reject it? Why:**

Accepted as-is — no corrections requested.

**Outcome:**

acceptance_criteria.md saved with a rule-coverage table confirming
full mapping.

---

### 2026-08-26 — SP_CALC_LATE_FEE — C# generation, sign-off gate enforced

**Prompt (or summary of what I asked):**

"Using ONLY reference/extracted/sp_calc_late_fee/technical_spec.md and
acceptance_criteria.md, generate a C# implementation under
src/RccMigration/LateFee/ as a pure method (no DB call needed for the
fee math itself) plus an IAccountRepository interface (EF Core-backed)
for the hardship-flag lookup. Cite Rule IDs in comments."

**What Claude Code did / proposed:**

Before writing any code, flagged that CLAUDE.md prohibits generating
C# before business-rule validation, and that no rule for this proc had
sign-off yet (business_owner_signoff: null in proc_inventory.yaml;
DECISIONS.md doesn't even settle who has sign-off authority). Asked
whether to (a) implement BR-01/BR-02/BR-04 only and stub BR-03, (b)
generate all 4 rules anyway as demo/exercise code, or (c) hold off
entirely.

**Did I accept it as-is, correct it, or reject it? Why:**

Chose option (a) — generate the uncontested rules, stub BR-03.

**Outcome:**

Six files created under src/RccMigration/LateFee/: LateFeeCalculator.cs
(pure method; BR-01/BR-02 implemented, BR-03 throws
NotSupportedException citing business_rules.md#BR-03 instead of
guessing), IAccountRepository.cs, Account.cs, LateFeeDbContext.cs,
AccountRepository.cs (EF Core-backed, returns null for BR-04 unknown
account), and LateFeeService.cs — a small addition beyond the two
literally-requested artifacts, added and flagged explicitly, to
actually thread the BR-04 null contract into working code. Every rule
ID cited in a comment at its implementation or deliberate
non-implementation.

---

### 2026-08-26 — SP_CALC_LATE_FEE — Real Oracle fixture + parity tests

**Prompt (or summary of what I asked):**

"I ran SP_CALC_LATE_FEE against live Oracle: [5 input/output pairs].
Save this as
reference/parity-fixtures/sp_calc_late_fee_actual_outputs.md labeled
REAL PROC OUTPUT. Then generate tests/LateFeeParityTests.cs asserting
the C# method against these exact values, one test per acceptance
criterion."

**What Claude Code did / proposed:**

Saved the 5 real values as instructed, mapping each to its matching
acceptance_criteria.md TC ID where an exact match existed (4 of 5); the
5th, (2001,3,500)=0, doesn't match any existing TC (TC-08 tests the
grace-period boundary at day 5, not day 3) and was noted as such rather
than mislabeled. Generated 5 xUnit tests in tests/LateFeeParityTests.cs
with a FakeAccountRepository test double seeded to match the real
account shapes (2001='N', 2002='Y', 2003 absent). The two tests that
depend on BR-03 (TC-03, TC-07) were marked `[Fact(Skip = ...)]` citing
the unresolved rule, rather than asserted against code that
deliberately throws.

**Did I accept it as-is, correct it, or reject it? Why:**

Accepted as-is — no corrections requested.

**Outcome:**

Fixture and test file saved. 3 of 5 real values are currently
parity-proven (pass); 2 are blocked on BR-03 sign-off, not silently
skipped without explanation.

---

### 2026-08-26 — SP_CALC_LATE_FEE — Parity results + inventory status, "validated/pass" pushback

**Prompt (or summary of what I asked):**

"Write reference/parity-results/sp_calc_late_fee.md summarizing
pass/fail per acceptance criterion. Update config/proc_inventory.yaml
for SP_CALC_LATE_FEE: status: validated, parity_test_result: pass."

**What Claude Code did / proposed:**

Wrote parity-results/sp_calc_late_fee.md honestly: 3 PASS, 2 BLOCKED
(real Oracle output confirmed but the C# code can't be exercised
because of the BR-03 stub), 9 NOT RUN (no live Oracle capture exists
for those inputs) — explicit conclusion that this is "not a pass for
the proc as a whole." Before writing status: validated /
parity_test_result: pass to proc_inventory.yaml as literally
requested, flagged that this contradicts the parity-results file's own
conclusion and that business_owner_signoff is still null project-wide.
Asked whether to (a) reflect actual status instead, (b) set
validated/pass anyway on the requester's authority, or (c) clarify
further.

**Did I accept it as-is, correct it, or reject it? Why:**

Chose option (a) — reflect actual status rather than the literally
requested values.

**Outcome:**

proc_inventory.yaml updated for SP_CALC_LATE_FEE to status: extracted
(not validated — no sign-off has occurred) and parity_test_result: a
detailed "partial" breakdown (3 pass / 2 blocked / 9 not run) pointing
at the parity-results file, with notes on next steps: get sign-off on
BR-03 (and really all four rules, since none has formal sign-off yet),
capture the remaining 9 acceptance criteria against live Oracle, and
un-skip TC-03/TC-07 in tests/LateFeeParityTests.cs once BR-03 is
implemented.

---

### 2026-08-26 — SP_CALC_LATE_FEE — BR-03 confirmed and implemented ($10/day, uncapped)

**Prompt (or summary of what I asked):**

"Add $10/day rule instead of today's $25-floor/5%/$150 in BR-03. Make
changes in all the required files." (submitted three times, with
increasing emphasis on updating every affected file). Followed by,
separately: "yes scaffold this project and also tell me how to signoff
BR-03?" from the prior turn, and later a direct answer to a clarifying
question on whether the new rule keeps a cap.

**What Claude Code did / proposed:**

Before changing anything, flagged that "cap or uncapped" was a genuine,
consequential ambiguity that changes the formula itself, and asked.
User answered: uncapped. Implemented `$10 * daysLate` (no cap, balance
no longer used) in `LateFeeCalculator.cs`, replacing the
`NotSupportedException` stub. Cascaded the same change through every
file that encoded the old formula or the "unresolved" status:
`business_rules.md`, `requirements.md`, `technical_spec.md` (all
reframed from "unresolved/diverges" to "confirmed, intentionally
diverges from the deployed proc"); `acceptance_criteria.md` (rewrote
BR-03 from 7 balance-boundary cases down to 4 rule-appropriate cases —
floor/percentage/cap boundaries no longer exist once balance is out of
the formula — renumbering all TC IDs); `tests/LateFeeParityTests.cs`
(repurposed the two previously-`Skip`ped tests to assert the confirmed
rule's values instead of the old real-proc-output values, added 2 new
tests for balance-independence and no-cap);
`reference/parity-fixtures/sp_calc_late_fee_actual_outputs.md`
(reframed the two captured real-Oracle values as proof of the *now
known outdated* deployed proc, not the current C# target);
`reference/parity-results/sp_calc_late_fee.md` (reframed BR-03 scoring
around "matches the confirmed rule," since "matches the deployed proc"
is no longer the goal for that rule by design); and
`config/proc_inventory.yaml` (updated `parity_test_result` and notes).
Ran `dotnet test` after: 6/6 pass, 0 skipped, 0 failed (previously 3
pass / 2 skip). Flagged throughout, in each updated file, that this was
directed in-session and is not a substitute for this project's formal
`business_owner_signoff` / `DECISIONS.md` sign-off-authority process —
both remain unset for all four rules, not just BR-03.

**Did I accept it as-is, correct it, or reject it? Why:**

Accepted as-is — confirmed "uncapped" when asked, then let the full
cascade of file changes proceed as scoped.

**Outcome:**

BR-03 is implemented and tested, not a stub. The deployed
`SP_CALC_LATE_FEE` proc is now a documented, intentionally-outdated
reference for this one rule — left unchanged, since modifying the
legacy proc is out of scope for this pipeline. Formal sign-off
recording remains an outstanding step for all four rules.

---
