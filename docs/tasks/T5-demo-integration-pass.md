# Task T5 - Demo Integration Pass

## Objective

Make the whole loop coherent from entry UI to battlefield combat.

## Dependencies

- `T1` must be accepted
- `T2` must be accepted
- `T3` must be accepted
- `T4` must be accepted

## Unlock rule

This task is unlocked only after `T1`, `T2`, `T3`, and `T4` are accepted.

## Read before implementing

- `docs/harness/executor-start.md`
- task cards for any dependencies this task integrates

## Expected outputs

- integrated playable flow
- small glue fixes required across previous tasks
- optional README usage update

## Acceptance criteria

- launch project -> select troops -> enter battle -> move units -> units fight enemies
- no required editor-only manual setup to demonstrate the loop
- no blocker errors in normal launch

## Submission requirements

Include runtime evidence for the full playable loop.

## Validator focus

- integration-focused diff
- no stealth rewrite of previously accepted work
