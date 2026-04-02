# Gdtoolkit Integration

This file documents how GDScript lint/format checks are integrated into review.

## Purpose

Use community-standard GDScript tooling for first-pass style and lint checks.

## Tools

- `gdlint`
- `gdformat`

These are typically provided by `gdtoolkit`.

## Review role

These tools are part of the automated gate, not a replacement for validator review.

They help catch:

- formatting drift
- basic style issues
- some common GDScript problems

They do not decide:

- task scope correctness
- semantic correctness
- fake implementations
- architecture quality

## Expected commands

```bash
gdlint game/test
gdformat --check game/test
```

## If unavailable

If the tools are not installed in the environment:

- the pipeline should report `SKIP` clearly
- validators should still run the remaining checks
- installation guidance should live here, not in chat only

## Installation guidance

Typical install:

```bash
python3 -m pip install --user gdtoolkit
```

If the environment uses a project virtualenv, install there instead.
