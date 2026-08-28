# Decisions — PL/SQL to C# Business Logic Extraction

Project-level decisions, settled once and applied to every proc after.
Update this file when a decision is made or changes — don't leave these
answers scattered across chat history.

## Target ORM
- Decision: Entity Framework (EF Core)
- Date / decided by:2026-08-26 / project owner
- Notes: Chosen for simplicity with the new REST API code path. Revisit as "split" only if a specific proc needs to share data access with an existing NHibernate-based legacy C# service.

## SnapLogic's role in this migration
- Decision: Existing integration middleware that the new C# code must interoperate with — not something this pipeline actively reconfigures or routes through during cutover.
- Date / decided by:2026-08-26 / project owner
- Notes: Treat SnapLogic as a fixed external dependency for now (e.g. it may call the new REST API once live). No cutover-routing logic is in scope for this pipeline unless revisited.

## Proc migration status lifecycle
- Decision: [Confirmed as proposed: not_started → extracted → validated → migrated → cutover
- Date / decided by: 2026-08-26 / project owner
- Notes: No amendment needed for current scope.

## Prioritization criteria for migration order
- Decision: Not yet formally weighted — deferred until more than one real proc is in the inventory. Default order for now: call frequency business risk > dependency chain > complexity.
- Date / decided by: 2026-08-26 / project owner
- Notes:

## Sign-off authority
- Decision: [who has authority to sign off on extracted business rules
  before code generation]
- Date / decided by:
- Notes: