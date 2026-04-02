# Godot Coding Standards

This file defines repository-level coding rules for Godot scenes and GDScript.

These rules are not only style preferences. They exist to improve:

- discoverability
- safe multi-agent editing
- reviewability
- performance hygiene

## Enforcement model

Each rule should be understood as one of:

- **script** — should be checked automatically where practical
- **agent-review** — checked by validator/reviewer
- **both** — script first, reviewer confirms intent/edge cases

## 1. File and naming rules

### 1.1 Scene and script naming

- Scene files must use `snake_case.tscn`
- Script files must use `snake_case.gd`
- Variables and functions must use `snake_case`
- Constants must use `UPPER_SNAKE_CASE`

Enforcement: **agent-review**

### 1.2 Main scene should have a clear main script

Core scenes should have one obvious owning script.
Avoid burying core behavior in many tiny anonymous node scripts.

Examples:

- `scenes/battle_root.tscn` -> `scripts/battle/battle_root.gd`
- `scenes/units/squad.tscn` -> `scripts/units/squad.gd`

Enforcement: **agent-review**

## 2. Script structure rules

### 2.1 Preferred declaration order

Use this order where practical:

1. `extends`
2. `class_name` if used
3. `signal`
4. `const`
5. `@export`
6. plain member vars
7. `@onready`
8. lifecycle methods
9. public methods
10. private methods

Enforcement: **agent-review**

### 2.2 Private helper methods should use `_` prefix

Examples:

- `_update_animation()`
- `_start_battle()`
- `_cleanup_selected_squads()`

Enforcement: **agent-review**

### 2.3 Avoid magic numbers in gameplay code

Important gameplay values should prefer:

- `const`
- `@export`
- config/resource data

Especially for:

- movement speed
- attack interval
- selection radius
- pathing thresholds
- detection ranges

Enforcement: **agent-review**

## 3. Architecture and responsibility rules

### 3.1 Keep input, simulation, and UI separated

Do not casually mix:

- input handling
- unit movement logic
- combat logic
- UI rendering/state

A single script may coordinate multiple concerns only if it is clearly the owning controller.

Enforcement: **agent-review**

### 3.2 Prefer explicit state over scattered booleans

For gameplay entities, prefer explicit states or enums where behavior meaningfully branches.

Examples:

- `IDLE`
- `MOVE`
- `ENGAGE`
- `ATTACK`
- `DEAD`

Enforcement: **agent-review**

### 3.3 Prefer stable public interfaces

Do not casually rename public methods that are used across scenes/scripts.

Examples of stable APIs:

- `set_move_target(...)`
- `set_selected(...)`
- `set_team(...)`
- `set_dead(...)`

Enforcement: **agent-review**

### 3.4 Prefer configuration separated from logic

When possible, troop/unit stats should not be spread as arbitrary inline literals across unrelated scripts.
Temporary hardcoding is acceptable for narrow tasks, but reviewers may request cleanup if it starts to spread.

Enforcement: **agent-review**

## 4. Scene tree access rules

### 4.1 Cache references when they are repeatedly used

Prefer cached references from:

- `@onready`
- one-time `get_node()` lookup
- explicit injection/registration

Avoid repeatedly traversing the tree for stable references.

Enforcement: **both**

### 4.2 Do not treat the scene tree as an implicit database

Do not rely on arbitrary node names/positions in the tree as the only source of gameplay truth.
Important gameplay rules should be represented in code or config.

Enforcement: **agent-review**

## 5. Hot-path and performance hygiene

### 5.1 Do not use expensive tree scans in hot loops

Inside `_process` / `_physics_process` or similar hot paths, avoid:

- `get_tree().get_nodes_in_group(...)`
- repeated `find_child(...)`
- repeated large `get_children()` scans

Enforcement: **both**

### 5.2 Do not leave `print()` in hot gameplay loops

Especially avoid `print()` inside:

- `_process`
- `_physics_process`
- combat loops
- unit update loops

Enforcement: **both**

### 5.3 Separate decision cadence from frame updates

When possible, expensive decisions such as target acquisition or regrouping should not happen every frame for every entity.
Movement updates may remain in `_physics_process`, but strategy/selection logic should prefer event-driven or lower-frequency updates.

Enforcement: **agent-review**

## 6. Task-boundary rules

### 6.1 Do not do opportunistic refactors in implementation tasks

Executors should not "clean up nearby code" unless:

- the task requires it
- the task card allows it
- the reviewer can clearly map it to the task

Enforcement: **both**

### 6.2 Planner/validator docs are protected

Executors must not edit planner/validator-owned docs unless explicitly authorized by the task.

Protected areas include:

- `docs/harness/`
- `docs/validation/`
- `docs/tasks/`

Enforcement: **script**

## 7. Temporary prototype rule

This is a prototype, not a final production codebase.
Temporary hardcoding is allowed when:

- the scope is narrow
- the task explicitly benefits from speed
- the behavior is still real and testable
- the hardcoding does not create obvious traps for the next task

Temporary is acceptable. Fake is not.

Enforcement: **agent-review**
