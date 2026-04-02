# Task Dependency Graph

This file defines which tasks are unlocked and which tasks are blocked.

## Rule

A task may only be assigned when all of its declared dependencies are in an accepted state:

- PASS
- PASS WITH NOTES (only if notes do not block dependent work)

If a dependency is incomplete or failed, the dependent task is locked.

## Dependency graph

- `T0` -> no dependencies
- `T1` -> depends on `T0`
- `T2` -> depends on `T0`
- `T3` -> depends on `T1`
- `T4` -> depends on `T2`, `T3`
- `T5` -> depends on `T1`, `T2`, `T3`, `T4`

## Why this shape

### T1 after T0

Need the harness and validation contract first.

### T2 after T0

UI flow can start after the harness is in place. It does not need to wait for final combat.

### T3 after T1

Reliable movement depends on the battlefield and obstacle/pathing layout being established first.

### T4 after T2 and T3

Combat should build on:

- the actual battle-entry flow from T2
- stable controllable movement from T3

Otherwise combat logic gets written against moving targets and placeholder assumptions.

### T5 after everything

Integration should be a final glue pass, not a substitute for unfinished feature work.

## Concurrency guidance for two developers

Safe parallelism:

- one developer on `T1`
- one developer on `T2`

Then:

- `T3` starts after `T1` passes
- `T4` starts after both `T2` and `T3` pass
- `T5` starts only after all feature tasks pass

## Validator rule

If an executor submits work for a locked task:

- mark the submission as **FAIL** or **NOT READY FOR REVIEW**
- cite the unmet dependency
- do not spend time on deep validation until the lock is cleared
