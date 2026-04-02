# Task T3 - Controlled Movement and Multi-Unit Command

## Objective

Make battlefield control reliable enough for demo use.

## Read before implementing

- `docs/harness/executor-start.md`
- current movement / selection / battle command files you must touch

## Expected outputs

Possible changed areas include:

- unit movement scripts
- selection handling
- battle command logic

## Acceptance criteria

- player can select controllable units
- issuing move commands consistently moves selected units
- multiple selected units do not all stack on the exact same destination point
- movement around obstacles still works after improvements

## Submission requirements

Include runtime evidence showing multi-unit command behavior, not just single-unit motion.

## Validator focus

- no fake pass by collapsing scope to one controllable unit
- formation/offset behavior is actually visible
