# Task Status Board

This is the shared task coordination board for the project.

Use it to track:

- lock/unlock status
- ownership
- current execution state
- review state
- blocking dependencies
- latest reviewed commit

Do not use chat history as the source of truth for task status.
Use this file.

## Status values

- `LOCKED` — dependencies not yet accepted
- `READY` — unlocked and available to assign
- `IN_PROGRESS` — currently being implemented
- `IN_REVIEW` — submitted and waiting for validation
- `PASS` — accepted
- `PASS_WITH_NOTES` — accepted with minor caveats
- `FAIL` — rejected; needs rework

## Board

| Task | Status | Owner | Blocked By | Latest Commit | Notes |
|---|---|---|---|---|---|
| T0 | PASS | planner | - | ee028d8 / 8f47a72 / 8cf979a | Harness baseline, progressive disclosure, performance review, dependency gates established |
| T1 | PASS_WITH_NOTES | executor | - | 6a671d1 | Battlefield terrain and obstacle layout accepted; runtime evidence should be strengthened in future submissions |
| T2 | PASS_WITH_NOTES | executor | - | 5bd12aa | [PASS WITH NOTES] Infantry: 3 units formation; Cavalry: 1 elite unit (move_speed=200, max_hp=80, selection_radius=24). Runtime evidence needs strengthening. Do not expand to movement/combat. Troop diffs are hardcoded; acceptable for now. .godot/ and .uid generation artifacts need consistent ignore/submit policy. |
| T3 | LOCKED | - | T1 | - | Wait for battlefield/pathing baseline |
| T4 | LOCKED | - | T2, T3 | - | Wait for battle entry and stable movement |
| T5 | LOCKED | - | T1, T2, T3, T4 | - | Final integration only |

## Update rules

### Planner may update

- task decomposition
- lock/ready state based on dependencies
- notes clarifying assignment expectations

### Executor may update

Only these fields for their assigned task:

- `Status`: `READY` -> `IN_PROGRESS` -> `IN_REVIEW`
- `Owner`
- `Latest Commit`
- short implementation note

Executors must not manually mark tasks as `PASS` or `PASS_WITH_NOTES`.

### Validator may update

- final review result
- latest reviewed commit
- validation notes
- reopening a failed task to `READY` if rework should begin again

## Coordination rule

If the board and chat disagree, the board wins until explicitly updated.
