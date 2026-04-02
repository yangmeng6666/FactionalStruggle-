# Godot Performance Rules

This file defines practical performance review rules for this project.

The goal is not premature optimization.
The goal is to reject obviously harmful patterns early.

## Principle

If a change is functionally correct but introduces a severe and avoidable gameplay performance problem, it should fail review.

## Red lines

### 1. Hot-loop tree scanning

Reject by default when gameplay code in hot paths repeatedly uses:

- `get_tree().get_nodes_in_group(...)`
- `find_child(...)`
- broad `get_children()` scans

inside `_process`, `_physics_process`, or equivalent per-entity hot loops.

Enforcement: **both**

### 2. Per-frame allocation-heavy logic

Reject by default when code repeatedly allocates avoidable arrays, dictionaries, or strings in hot loops without justification.

Enforcement: **agent-review**

### 3. Naive all-to-all gameplay logic

Reject by default when every unit checks every other unit every frame without cadence control or pruning.

Enforcement: **both**

### 4. Frequent expensive world recomputation

Reject by default when navigation or large world data is rebuilt too often for small local changes.

Enforcement: **agent-review**

### 5. Logging/debug leftovers in hot loops

Reject by default when `print()` or heavy debug behavior remains in hot gameplay paths.

Enforcement: **both**

## Prototype exception

Small inefficiencies are acceptable if all of the following are true:

- they are not in a hot path
- they do not scale badly with unit count
- they are local to the task
- they do not create likely future traps

## Review posture

Reviewers should ask:

- is this in a hot path?
- does this scale with entity count?
- is this avoidable right now?
- will this likely spread if accepted?
