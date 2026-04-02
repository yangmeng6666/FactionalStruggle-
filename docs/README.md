# FactionalStruggle Harness Docs

This docs tree is organized for progressive disclosure.

Start here, then read only the next file your role needs.

## Roles

- **Planner**: breaks work into sub-tasks and maintains task definitions.
- **Executor**: reads only the assigned task card plus minimal referenced knowledge.
- **Validator**: reads the validation protocol plus the assigned task card.

## Reading Paths

### If you are the planner

1. Read `docs/harness/overview.md`
2. Read or update task cards under `docs/tasks/`
3. Use validation rules under `docs/validation/`

### If you are the executor

Read only:

1. `docs/harness/executor-start.md`
2. the assigned task card in `docs/tasks/`
3. any file explicitly referenced by that task card

Do not read the full docs tree unless the task card tells you to.
Do not edit planner/validator-owned docs.

### If you are the validator

Read only:

1. `docs/harness/validator-start.md`
2. the assigned task card in `docs/tasks/`
3. `docs/validation/protocol.md`
4. `docs/validation/task-checklist.md`

## Design Principle

These docs are intentionally map-shaped, not book-shaped.

The goal is to give agents:

- a clear starting point
- the minimum next knowledge needed
- stable task boundaries
- explicit validation rules

Not a giant wall of instructions.
