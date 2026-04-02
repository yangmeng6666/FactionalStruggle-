# Validation Protocol

## Validation Order

Validate in this order:

1. scope
2. requirement mapping
3. runtime evidence
4. acceptance criteria
5. regression sanity

## 1. Scope

Use:

- `git diff --stat`
- `git diff`

Check:

- only expected files changed
- no unrelated churn
- planner/validator-owned docs were not modified by executor

## 2. Requirement Mapping

Every changed file should map to a requirement in the assigned task card.
If a file does not map cleanly, flag it.

## 3. Runtime Evidence

Minimum acceptable evidence:

- exact command used
- whether project loaded/launched
- observed result
- any errors encountered

Weak evidence examples:

- "should work"
- "code compiles in theory"
- "not run, but logic is simple"

## 4. Acceptance Criteria

Judge against the task card only.
Do not silently add hidden criteria unless needed for correctness.

## 5. Regression Sanity

Quickly check whether the change obviously broke baseline functionality.

## 6. Performance Review

For gameplay/runtime tasks, also review against:

- `docs/validation/performance-red-lines.md`

A task should be marked **FAIL** if it introduces a severe and avoidable performance problem, even when functionally correct.

## Result Labels

### PASS

All required criteria met and evidence is credible.

### PASS WITH NOTES

Task is functionally acceptable, but there are minor issues, caveats, or cleanup items.

### FAIL

Any of the following:

- missing required evidence
- criteria not met
- scope violation
- blocking parser/runtime issue
- change is mostly stubbed or cosmetic
