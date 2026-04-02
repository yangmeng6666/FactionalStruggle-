# Script Checks

This file lists the first-pass automated checks expected in review.

## `scripts/review/check_task_rules.py`

Checks:

- task exists in dependency graph
- task exists in status board
- protected docs were not modified by executors
- changed files look consistent with task scope hints

## `scripts/review/check_godot_rules.py`

Checks:

- hot-loop use of `get_nodes_in_group`
- hot-loop use of `find_child`
- hot-loop use of `print`
- possible all-to-all scans in hot paths (heuristic)

## `scripts/review/check_commit_evidence.py`

Checks:

- commit message contains `Runtime evidence:`
- commit message contains `Command:`
- commit message contains at least one result-style section

## `scripts/review/run_all_checks.py`

Wrapper that runs all configured checks in sequence and returns a combined status.

## `scripts/review/write_review_record.py`

Creates a standardized review record file under `docs/validation/records/`.

## `scripts/review/run_godot_import.sh`

Runs:

```bash
godot --headless --path game/test --import
```

Use the project's configured Godot binary if needed.
