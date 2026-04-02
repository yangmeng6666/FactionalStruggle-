# Executor Start

Read this first. Then stop.

## Your job

Implement exactly one assigned task and keep the status board current.

## What to read next

Read only:

1. confirm your task is unlocked in `docs/tasks/dependency-graph.md`
2. check `docs/tasks/status-board.md`
3. your assigned task card in `docs/tasks/`
4. any files explicitly listed in that task card under "Read before implementing"

Do not browse the whole docs tree by default.

## Constraints

- change only files needed for the task
- avoid unrelated refactors
- do not edit planner/validator-owned docs
- keep the implementation surface small and reviewable
- avoid obvious performance traps in gameplay hot paths
- follow project rules under `docs/standards/`

Read:

- `docs/standards/godot-coding-standards.md`
- `docs/standards/godot-performance-rules.md`

if your task touches Godot gameplay/runtime logic.

## Required deliverables

Your submission must include:

1. a git commit
2. runtime evidence
3. a short summary of what changed
4. a filled submission using `docs/harness/submission-template.md`
5. a status board update in `docs/tasks/status-board.md`

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
