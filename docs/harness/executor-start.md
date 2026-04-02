# Executor Start

Read this first. Then stop.

## Your job

Implement exactly one assigned task.

## What to read next

Read only:

1. confirm your task is unlocked in `docs/tasks/dependency-graph.md`
2. your assigned task card in `docs/tasks/`
3. any files explicitly listed in that task card under "Read before implementing"

Do not browse the whole docs tree by default.

## Constraints

- change only files needed for the task
- avoid unrelated refactors
- do not edit planner/validator-owned docs
- keep the implementation surface small and reviewable
- avoid obvious performance traps in gameplay hot paths

Read `docs/validation/performance-red-lines.md` if your task touches runtime gameplay logic.

## Required deliverables

Your submission must include:

1. a git commit
2. runtime evidence
3. a short summary of what changed

## Required runtime evidence

At minimum provide:

- exact run command
- whether load/run succeeded
- parser/runtime errors if any
- concise observation of behavior

Preferred:

- terminal output
- screenshot
- short note describing what was tested

## What not to do

- do not claim completion without running something
- do not broaden scope because it feels convenient
- do not rewrite systems outside the task
