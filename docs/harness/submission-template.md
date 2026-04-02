# Executor Submission Template

Use this template when submitting a task for review.

## Submission Header

- Task ID:
- Task Title:
- Dependency status checked: yes / no
- Status board updated: yes / no
- Commit SHA:

## Scope Summary

- Files changed:
- Why each file changed:

## Run Evidence

- Run command:
- Environment / scene / entry used:
- Result: success / failed
- Parser/runtime errors:
- Observed behavior:

## Acceptance Mapping

- criterion 1 -> how it was satisfied
- criterion 2 -> how it was satisfied
- criterion 3 -> how it was satisfied
- criterion 4 -> how it was satisfied

## Performance Self-Check

- hot-loop scene-tree scans introduced? yes / no
- avoidable per-frame allocations introduced? yes / no
- naive all-to-all logic introduced? yes / no
- if yes to any, justify:

## Known Limits

- remaining issues:
- caveats:
- follow-up suggestions:

## Ready for Review

- [ ] I ran the relevant code path
- [ ] I checked the task was unlocked before starting
- [ ] I updated `docs/tasks/status-board.md`
- [ ] I did not edit planner/validator-only docs
