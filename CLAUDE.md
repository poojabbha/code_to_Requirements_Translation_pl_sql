# Project: PL/SQL to C# Business Logic Extraction

## What this project is

An incremental modernization effort: extract embedded business logic out
of thousands of Oracle PL/SQL stored procedures and move it into a C#
web application exposed via REST API, with Oracle data access through
NHibernate and/or Entity Framework. Legacy stored procs stay live until
each one's logic has been safely extracted, validated, and migrated —
this happens proc-by-proc, over time, not all at once.

## This is a production deliverable, not a POC

- Build a repeatable extraction → validation → generation → parity-test
  pipeline, not a one-off manual translation of a single proc
- Automated parity tests proving the generated C# logic matches the
  original PL/SQL's behavior — not just code that "reads correctly"
- No hardcoded connection strings or credentials
- Documented well enough that someone else could apply this pipeline to
  the next stored proc without you in the room
- Track per-proc migration status in a config/data file, not in chat
  history or memory

## Context to build on

- The Oracle codebase has thousands of stored procedures, many with
  embedded business logic that needs to move into the application layer.
- Target stack: C# web application, REST API, Oracle data access via
  NHibernate and/or Entity Framework — confirm which is standard for new
  work before generating code; both being named suggests either an open
  decision or a legacy/new split across services.
- SnapLogic sits somewhere in the integration layer — clarify whether
  it's existing middleware this pipeline needs to interoperate with, or
  something intended to actively route traffic between legacy and new
  code paths during a phased cutover. These lead to different designs.
- Business logic in these procs is often financial/policy-critical.
  Every extracted rule must be validated by a business/domain expert
  before it's used to generate replacement code, and generated code must
  be proven behaviorally equivalent to the original — not just reviewed
  for plausibility.

## Approach: build a pipeline, not a one-off translation

Given the real scope, this session's deliverable is a repeatable process
demonstrated end-to-end on a small, representative set of procs — not a
hand-crafted translation of just one.

1. **Catalog.** Track stored procs and their migration status in
   `config/proc_inventory.yaml` (see the example file). Suggested status
   lifecycle: `not_started` → `extracted` → `validated` → `migrated` →
   `cutover`.
2. **Prioritize.** Define and document real criteria for migration order
   — call frequency, complexity, dependency on other procs, business
   risk. Don't migrate in whatever order procs happen to be opened.
3. **Reverse-engineer (per proc).** Produce plain-language requirements,
   numbered business rules, and a technical spec (inputs, outputs, side
   effects).
4. **Validate (per proc).** Stop. Get explicit business/domain sign-off
   on the extracted rules before generating any replacement code.
5. **Generate (per proc).** Implement the equivalent business logic in
   C#, using the confirmed ORM, exposed via REST API where applicable.
6. **Prove parity (per proc).** Run the same inputs against the original
   stored proc and the new C# logic; confirm matching outputs. This is
   the actual proof of correctness — a code review is not.
7. **Update the inventory status** and move to the next proc.

## Keep proc source and data out of chat/prompt context

Thousands of stored procs won't fit in context and shouldn't be pasted
in regardless. Export or reference proc source on disk under
`reference/procs/`, and have Claude Code read/analyze it via file paths
and scripts — not by pasting full proc bodies into chat repeatedly.

## Where things get stored

Settled project-level decisions (ORM, SnapLogic's role, status lifecycle,
prioritization criteria, sign-off authority) go in `DECISIONS.md`. Per-
proc pipeline output goes under `reference/`: original source in
`reference/procs/`, reverse-engineered requirements/business
rules/technical spec/sign-off in `reference/extracted/<proc_name>/`, and
parity test results in `reference/parity-results/<proc_name>.md`.
`config/proc_inventory.yaml` is the index pointing at all of it — it
tracks status, not the underlying substance.

## Working agreement (Spec-Driven Development)

1. **Specify** — for the proc(s) in scope this session, confirm inputs,
   outputs, and business rules before generating any code.
2. **Plan** — propose the pipeline design and confirm ORM/architecture
   before building tooling.
3. **Tasks** — build the pipeline generically, then run it against 2-3
   representative procs (mix of simple and complex) — don't hand-tune it
   to just one.
4. **Implement** — build incrementally; validate parity at each step,
   not only at the end.

## Deliverables I will evaluate

- `ai-journal/` — log of key prompts, decisions, and corrections
- A working pipeline applied to at least 2-3 real stored procs end to
  end, with the human validation step visibly built in, not skipped
- Parity tests proving the generated C# logic matches original PL/SQL
  output on real/sample inputs
- `config/proc_inventory.yaml` reflecting real status, not placeholders
- A clear explanation of how this pipeline scales to the rest of the
  codebase

## Do not

- Do not attempt or promise extraction of "the entire codebase" this
  session
- Do not generate replacement C# code before business-rule validation
  for that specific proc
- Do not hardcode Oracle connection strings or credentials
- Do not treat "compiles and looks plausible" as proof of correctness —
  require parity testing against real inputs