# Task T1 - Battlefield Terrain and Obstacles

## Objective

Turn the current battle scene into an actual battlefield with visible terrain and navigationally meaningful obstacles.

## Dependencies

- `T0` must be accepted

## Unlock rule

This task is unlocked only after `T0` is accepted.

## Read before implementing

- `docs/harness/executor-start.md`
- `game/test/scenes/battle_root.tscn`
- any directly referenced scene/script files you must touch

## Expected outputs

Possible changed areas include:

- `game/test/scenes/battle_root.tscn`
- new terrain/obstacle helper scenes/resources if needed
- small script support only if required

## Acceptance criteria

- battle scene visually communicates traversable area vs blocked area
- there are multiple obstacles that force route changes
- selected units moving to a point must route around obstacles instead of trying to walk straight through them
- scene remains loadable in Godot

## Submission requirements

Include runtime evidence showing the battle scene loads and pathing is meaningfully affected by obstacles.

## Validator focus

- obstacle/pathing changes are real, not visual-only
- diff stays focused on terrain/nav work
