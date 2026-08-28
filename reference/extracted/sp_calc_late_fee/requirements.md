# Requirements — Late Fee Calculation

Plain-language summary for non-technical review. Written for business
and domain reviewers, not developers — no code or line references.
Based on `business_rules.md` in this same folder.

## Purpose

This calculation determines whether a late fee should be charged on a
customer's account, and if so, how much. It looks at how many days a
payment is overdue, the customer's outstanding balance, and whether
the account is flagged for financial hardship, and returns a single
dollar amount (or no amount, in one specific case explained below).

## When it runs (trigger)

It's run for one account at a time, whenever the business needs to
know the late fee for that account — for example, during billing or
statement processing, once the system knows how many days a given
payment is overdue and what that customer currently owes.

## The rules

**1. Short delays don't get charged (grace period).**
If a payment is 5 days late or less, there is no late fee — $0.

**2. Hardship accounts are never charged a late fee.**
If the account is flagged for financial hardship, no late fee is
charged, no matter how late the payment is or how large the balance.

**3. The standard fee amount (confirmed).**
For an account that is more than 5 days late and not flagged for
hardship, the late fee is $10 for every day the payment is late, with
no maximum — a payment 100 days late is a $1,000 fee. The customer's
balance has no effect on this fee at all. **This is confirmed as the
correct rule, and it does not match what the deployed system currently
computes** — see below for what that means in practice.

**4. Unrecognized accounts.**
If the account number given doesn't match any real account on file,
the calculation doesn't return a fee amount at all — not $0, and not
an error message. It comes back blank/unknown.

## Rule 3 — decision record (previously open questions)

Rule 3 conflicted with what the deployed system computes when it was
first extracted. That conflict has since been resolved by direct
decision, recorded here for anyone reading this later:

- **Which is correct** — the $10/day rule, or the old $25-minimum/5%/
  $150-cap rule? **Decided: the $10/day rule.** The system currently
  running in production/test is out of date and has not been changed
  to match — this is a known, accepted gap, not an oversight.
- **Does the fee keep growing forever, or is there a maximum?**
  **Decided: no maximum.** Unlike the old $150 cap, this fee has no
  ceiling.
- **How is "days late" determined?** **Decided:** it's provided fresh
  on each calculation (whoever calls this is expected to pass in the
  current number of days late); the fee naturally grows over time
  because that input grows, not because this calculation remembers
  anything between calls.

This decision was made directly by the project owner in a Claude Code
session on 2026-08-26. It has **not yet** gone through this project's
formal sign-off recording (the business-owner sign-off field in
`config/proc_inventory.yaml`, or the sign-off-authority decision in
`DECISIONS.md` — both still unset). That paperwork is a separate,
still-outstanding step; it doesn't change what was decided here, but it
means this decision isn't formally attributed to a named business
owner yet.

Rules 1, 2, and 4 are all directly reflected in, and match, the
system's current behavior — no open questions on those.
