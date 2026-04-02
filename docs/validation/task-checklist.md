# Task Validation Checklist

Use this template when validating each executor submission.

---

## Task Record

- Task ID:
- Task Title:
- Commit SHA:
- Validator:
- Date:

## 0. Dependency Gate

- [ ] task was unlocked when work started
- [ ] all declared dependencies are already accepted

Notes:

## 1. Scope Check

### `git diff --stat`

Paste summary here.

### Files changed

List changed files here.

### Scope result

- [ ] only expected files changed
- [ ] no unrelated refactor
- [ ] no planner/validator-owned docs modified by executor

Notes:

## 2. Requirement Mapping

Map each changed file to a task requirement.

- file -> reason
- file -> reason

Result:

- [ ] all changed files are justified

Notes:

## 3. Runtime Evidence Check

### Run command

Paste exact command here.

### Output / evidence

Paste output summary here.

### Observation

Describe what was observed.

Result:

- [ ] project/script loaded successfully
- [ ] claimed feature was actually exercised
- [ ] no blocking parser/runtime issue remains

Notes:

## 4. Acceptance Criteria Check

Copy task acceptance criteria and mark each.

- [ ] criterion 1
- [ ] criterion 2
- [ ] criterion 3
- [ ] criterion 4

Notes:

## 5. Regression Sanity Check

- [ ] previously working flow still intact
- [ ] no obvious accidental breakage introduced

Notes:

## 6. Performance Review

- [ ] no severe hot-loop scene-tree scans introduced
- [ ] no obvious avoidable allocation-heavy per-frame logic introduced
- [ ] no naive all-to-all gameplay logic introduced without justification
- [ ] no other red-line issue from `docs/validation/performance-red-lines.md`

Notes:

## Final Result

- [ ] PASS
- [ ] PASS WITH NOTES
- [ ] FAIL

## Follow-up

- next action:
- blockers:
- optional cleanup:
