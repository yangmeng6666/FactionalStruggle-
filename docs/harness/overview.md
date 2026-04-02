# Harness Overview

## Purpose

This repository uses a planner / executor / validator split.

The harness should reduce ambiguity without over-prescribing implementation.

We want:

- clear task contracts
- small readable task cards
- observable outputs
- diff-based validation
- runtime evidence attached to every implementation task

## Progressive Disclosure Rules

1. Do not give every agent every document up front.
2. Start from role-specific entrypoints.
3. Task cards should be short and concrete.
4. Deep detail belongs in referenced files, not in the top-level map.
5. Validation should rely on code, diffs, and execution evidence more than prose.

## Repo Scope

Primary project path:

- `game/test`

## Planner-owned surfaces

- `docs/harness/`
- `docs/tasks/`
- `docs/validation/`

Executors may read these, but should only edit implementation files unless explicitly told otherwise.

## Task Lifecycle

1. Planner defines or updates a task card.
2. Executor reads only the assigned task card and minimal references.
3. Executor implements and commits changes.
4. Executor provides runtime evidence.
5. Validator reviews `git diff` plus evidence.
6. Validator records PASS / FAIL / PASS WITH NOTES.
