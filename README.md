# PL/SQL to C# Business Logic Extraction — Getting Started

Read `CLAUDE.md` first for project context and the working agreement.
This file is your kickoff checklist.

## The bar for this deliverable

A working, production-ready **extraction pipeline** — not a manual,
one-off translation of a single stored proc. Target stack: C# web
application / REST API, Oracle data access via NHibernate and/or Entity
Framework, migrating away from thousands of legacy PL/SQL procs over
time.

## What will be evaluated when you present

- [ ] An AI journal (`ai-journal/`) — key prompts, decisions, corrections
- [ ] The pipeline applied to 2-3 real procs end to end: reverse-engineer
      → validate → generate → parity test
- [ ] `config/proc_inventory.yaml` reflecting real, not placeholder,
      status
- [ ] A clear explanation of how this scales to the rest of the codebase

---

## Where things get stored

**Project-level decisions** (the Phase 0 answers below) go in
`DECISIONS.md` — settled once, applied to every proc after.

**Per-proc artifacts** (Phase 1 pipeline output) go under `reference/`,
one subfolder per proc:

```
reference/
  procs/<proc_name>.sql              <- exported original source
  extracted/<proc_name>/
    requirements.md                   <- reverse-engineering output
    business_rules.md                 <- reverse-engineering output
    technical_spec.md                 <- reverse-engineering output
    signoff.md                        <- who approved, when, notes
  parity-results/<proc_name>.md      <- input/output diffs from testing
```

`config/proc_inventory.yaml` stays the index — one row per proc with its
status — pointing at the folders above rather than duplicating their
content. Gitignore `reference/` — it holds production business logic.
Don't paste full proc bodies or extracted content into chat repeatedly —
point Claude Code at these file paths.

---

## TODOs

### Phase 0 — Discovery
Record each answer below in `DECISIONS.md` as it's settled.
- [ ] Confirm the target ORM: NHibernate, Entity Framework, or a defined
      split between them.
- [ ] Clarify SnapLogic's role in this specific migration — existing
      integration to interoperate with, or active routing during a
      phased cutover.
- [ ] Export or identify 2-3 representative stored procs to work with
      this session — a mix of simple and complex, ideally ones whose
      correct behavior is already well understood so parity can be
      checked confidently.
- [ ] Confirm the migration status lifecycle for procs (proposed:
      `not_started` → `extracted` → `validated` → `migrated` →
      `cutover`).
- [ ] Define prioritization criteria for migration order — call
      frequency, complexity, dependency chain, business risk.
- [ ] Confirm who signs off on extracted business rules before code
      generation.

### Phase 1 — Build the pipeline
- [ ] Proc inventory tracking (`config/proc_inventory.yaml`)
- [ ] Reverse-engineering step: proc source → requirements + business
      rules + technical spec
- [ ] Validation checkpoint — a real gate that blocks code generation
      until sign-off is recorded, not a step that can be skipped
- [ ] Code generation step: validated business rules → C# implementation
      via the confirmed ORM
- [ ] Parity testing: same inputs run against the original proc and the
      new C# logic, outputs diffed
- [ ] Wire generated logic into a REST API endpoint where applicable

### Phase 2 — Run it end to end
- [ ] Run all 2-3 chosen procs through the full pipeline
- [ ] Document parity test results, including any edge cases found
- [ ] Update `proc_inventory.yaml` status for each

### Phase 3 — Make it production-ready
- [ ] Automated tests for the pipeline itself, not just the generated
      code
- [ ] Structured logging of pipeline runs
- [ ] Document how to onboard the next stored proc using this pipeline
- [ ] No hardcoded credentials or connection strings

### Phase 4 — Prep for presentation
- [ ] Keep `ai-journal/` updated as you go
- [ ] Be ready to run the pipeline live on a proc and show: extracted
      spec → validation → generated code → parity test result

## Folder guide

```
CLAUDE.md          <- project context Claude Code loads automatically
README.md          <- this file
DECISIONS.md        <- settled Phase 0 project-level decisions
config/            <- proc_inventory.yaml (per-proc migration status)
reference/          <- per-proc source, extracted docs, parity results (gitignored)
ai-journal/         <- your prompt/decision log (template inside)
.claude/settings.json <- baseline permissions (adjusted for dotnet CLI)
```