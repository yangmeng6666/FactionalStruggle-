# Task T6 - Combat Range Tuning and Feedback Polish

## Objective

Refine melee combat readability so units only auto-engage nearby enemies and combat clearly shows attack and hurt feedback.

## Dependencies

- `T4` must be accepted
- `T5` must be accepted

## Unlock rule

This task is unlocked only after both `T4` and `T5` are accepted.

## Read before implementing

- `docs/harness/executor-start.md`
- task cards for `T4` and `T5`
- current combat, battle, unit, and animation files you must touch

## Expected outputs

Possible changed areas include:

- unit scripts
- battle coordination scripts
- unit scenes or sprite frame resources
- optional simple combat config or tuning data
- optional lightweight HUD or VFX feedback

## Acceptance criteria

- units do not auto-acquire enemies from across the battlefield at battle start
- auto-attack target acquisition is gated by a tuned local detection range
- once a valid enemy enters that local range, units can still move into melee range and attack
- attack actions have visible presentation tied to attack timing
- taking damage has visible hurt feedback tied to damage reception
- combat readability improves without breaking the playable loop from `T5`

## Notes

Simple is enough:

- a fixed local detection range is acceptable
- animation-first feedback is acceptable; no full VFX system is required
- prefer readable combat timing over extra effects
- do not regress pairwise engagement or movement command behavior

## Submission requirements

Include runtime evidence showing:

- battle start no longer causes immediate map-wide aggro
- enemies begin fighting only after entering local auto-attack range
- attack presentation is visible
- hurt presentation is visible

## Validator focus

- range tuning changes actual combat acquisition behavior
- attack and hurt feedback are connected to combat logic, not decorative only
- the integrated `T5` gameplay loop still works
