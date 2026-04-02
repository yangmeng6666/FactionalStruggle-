# Performance Red Lines

This file defines performance review rules for gameplay code.

The project is a game prototype, so correctness alone is not enough.
Code review must reject changes that introduce clearly harmful performance patterns without strong justification.

## Rule

If a change introduces a severe and avoidable performance problem, the validator should mark the task as **FAIL**, even if the feature appears to work functionally.

## Why

In a game, bad patterns compound quickly:

- per-frame waste scales with unit count
- temporary hacks become permanent architecture
- performance regressions are harder to remove later than to block early

## Red-line patterns

The following patterns should be treated as default reject conditions unless there is explicit justification and measured evidence.

### 1. Heavy scene-tree searches inside hot loops

Examples:

- calling `get_tree().get_nodes_in_group()` every `_process` / `_physics_process`
- repeated `find_child()` / `get_children()` scans every frame per unit
- repeatedly traversing large node hierarchies in per-unit updates

Preferred direction:

- cache references
- update registries on spawn/despawn
- centralize lookups when possible

### 2. Per-frame allocation-heavy behavior in gameplay loops

Examples:

- creating large temporary arrays/dictionaries/strings every frame
- repeated string building for debug/UI in hot paths
- repeated object creation in `_process` / `_physics_process` when avoidable

Preferred direction:

- reuse containers where possible
- move work out of hot loops
- compute on events instead of every frame

### 3. N-squared behavior introduced casually for unit-vs-unit logic

Examples:

- every unit scanning every other unit each frame without constraints
- pair matching implemented as full all-to-all checks in hot loops
- repeated global nearest-target scans without cadence control or pruning

Preferred direction:

- throttle target acquisition
n- use team registries / local queries / coarse filtering
- separate infrequent decision updates from per-frame movement

### 4. Rebuilding navigation / expensive world data too often

Examples:

- rebuilding nav meshes or obstacle data every frame
- regenerating map-wide data on small local changes
- repeated full-scene recomputation when incremental updates would do

Preferred direction:

- static bake where possible
- event-driven updates
- keep expensive world recomputation rare and explicit

### 5. Logging or debug drawing left in hot gameplay paths

Examples:

- `print()` in per-frame code
- excessive debug draw updates on every unit every frame
- spammy logging in combat/movement loops

Preferred direction:

- gated debug flags
- sample-based logging
- dev-only instrumentation

### 6. Cosmetic work mixed into hot simulation loops

Examples:

- repeated UI rebuilds driven from every unit each frame
- expensive animation/state checks duplicated unnecessarily
- sorting/recomputing presentation data every frame without need

Preferred direction:

- separate simulation from presentation
- update UI on state change or low-frequency ticks

## Not every inefficiency is a blocker

The validator does not need perfect optimization.
Reject only when the issue is:

- severe enough to matter soon
- clearly avoidable
- inconsistent with prototype scale goals

## Validator action

If a red-line pattern appears:

1. identify the hot path
2. cite the exact file/function behavior
3. explain why it scales poorly
4. mark **FAIL** unless there is strong justification and evidence

## Executor expectation

When implementing gameplay systems, assume reviewers will check for:

- hot-loop scans
- avoidable allocations
- naive all-to-all logic
- unnecessary recomputation

Design for "prototype-fast but not obviously self-sabotaging."
