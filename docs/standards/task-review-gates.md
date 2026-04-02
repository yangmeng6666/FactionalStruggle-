# Task Review Gates

This file defines the review gates every implementation task must pass.

## Rule source

This document is the source of truth for task-level gates.
Scripts should enforce what they can.
Validators should enforce the rest.

## Gates

### Gate 0 - Dependency gate

The task must be unlocked according to `docs/tasks/dependency-graph.md`.

Enforcement: **script**

### Gate 1 - Status board gate

The task must have a valid status progression in `docs/tasks/status-board.md`.

Expected progression:

- `READY`
- `IN_PROGRESS`
- `IN_REVIEW`
- final validator state

When a task is submitted for review, the status board should already reference the submitted commit in `Latest Commit`.

Enforcement: **script + agent-review**

### Gate 2 - Protected docs gate

Executors must not modify planner/validator-owned docs unless explicitly allowed.

Enforcement: **script**

### Gate 3 - Runtime evidence gate

Implementation submissions must include runtime evidence in the commit message or attached submission record.

Minimum expected evidence:

- `Runtime evidence:` section
- `Command:` line
- result summary

Enforcement: **script + agent-review**

### Gate 4 - Scope gate

Changed files must map cleanly to the assigned task.

Enforcement: **script + agent-review**

### Gate 5 - Import/parse gate

Godot import/parse must succeed for the target project.

Recommended command:

```bash
godot --headless --path game/test --import
```

Enforcement: **script**

### Gate 6 - Performance gate

The change must not violate the red lines in `docs/standards/godot-performance-rules.md`.

Enforcement: **script + agent-review**

### Gate 7 - Acceptance gate

The actual behavior must satisfy the task card's acceptance criteria.

Enforcement: **agent-review**

## Final decision labels

- `PASS`
- `PASS_WITH_NOTES`
- `FAIL`
- `NOT_READY_FOR_REVIEW`
