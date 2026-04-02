# Review Pipeline

This file defines the intended order of automated and manual review.

## Source of truth model

- `docs/standards/` defines rules
- `scripts/review/` executes scriptable checks
- validators perform semantic review for what scripts cannot decide

## Review order

### 0. Dependency and status checks

Check:

- task unlock status
- status board state

### 1. Automated checks

Run:

- task-rule checks
- Godot-rule checks
- commit-evidence checks
- Godot import check

### 2. Agent review

Review:

- diff intent
- scope correctness
- acceptance criteria
- performance trends
- fake implementations / semantic cheating

### 3. Final verdict

One of:

- `PASS`
- `PASS_WITH_NOTES`
- `FAIL`
- `NOT_READY_FOR_REVIEW`

### 4. Record outcome

Write the review result into:

- `docs/tasks/status-board.md`
- `docs/validation/records/<task>-<commit>.md`

## Principle

If a rule can be checked reliably by script, prefer script.
If a rule depends on semantic or architectural judgment, document it and let the validator decide.
