# Task T4 - Pair Combat and Melee Engagement

## Objective

Implement a simple combat loop where opposing units can engage and fight in pairs.

## Read before implementing

- `docs/harness/executor-start.md`
- current combat/battle/unit files you must touch

## Expected outputs

Possible changed areas include:

- unit scripts
- battle coordination scripts
- optional simple combat config/data
- optional temporary HUD feedback

## Acceptance criteria

- opposing units can detect valid enemies
- units can move into engagement range and attack
- combat produces visible state change such as HP loss, death, or removal
- pairwise engagement behavior exists
- the battle can visibly progress because of combat

## Notes

Simple is enough:

- nearest target
- one target at a time
- fixed damage interval
- basic death handling

## Submission requirements

Include runtime evidence showing combat initiation, attack resolution, and visible combat outcomes.

## Validator focus

- actual combat logic exists
- not animation-only or purely decorative
