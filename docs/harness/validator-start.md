# Validator Start

Read this first. Then read only the task card and validation protocol.

## Your job

Determine whether the assigned executor submission passes, update the status board, and write a durable review record.

## Read next

1. `docs/tasks/dependency-graph.md`
2. `docs/tasks/status-board.md`
3. assigned task card in `docs/tasks/`
4. `docs/validation/protocol.md`
5. `docs/validation/task-checklist.md`
6. `docs/standards/godot-coding-standards.md` for Godot tasks
7. `docs/standards/godot-performance-rules.md` for gameplay/runtime tasks
8. `docs/automation/review-pipeline.md`
9. `docs/harness/review-template.md`

## Core principle

Validation is based on:

- the actual diff
- the task contract
- execution evidence

Not on intent or persuasive prose.

## Decision outputs

A task result must be one of:

- PASS
- PASS WITH NOTES
- FAIL

## Default skepticism

If runtime evidence is missing or weak, do not over-credit the task.
