# FactionalStruggle Demo Plan & Verification

## Goal

Build a playable temporary vertical-slice demo in Godot with:

1. A battle scene with terrain/obstacles.
2. A simple temporary troop-selection UI before entering battle.
3. Entering the battlefield from the selection UI.
4. Units can be controlled to move.
5. Units can pair off and fight each other.

This document is planner/validator owned. Executors may read it but must not modify it.

## Working Model

We are explicitly using a lightweight Harness Engineering style split:

- **Planner**: decomposes work into concrete sub-tasks with clear output and acceptance criteria.
- **Executor**: only implements the assigned sub-task.
- **Validator**: checks the executor's change by reviewing `git diff` and runtime evidence.

The harness goal is not to micromanage implementation details, but to provide:

- clear task boundaries
- observable outputs
- executable validation
- explicit pass/fail criteria

## Repo Scope

Primary Godot project path:

- `game/test`

Current observed baseline:

- Existing selection and move-command skeleton exists.
- Existing `NavigationAgent2D` movement exists.
- Existing battle scene exists but terrain/obstacles/combat loop are incomplete.
- No troop-selection pre-battle flow yet.

## Ground Rules

### Planner/Validator-only file

This file and files under `docs/validation/` are planner/validator controlled.
Executors should not edit them.

### Executor constraints

For each sub-task, the executor should:

1. change only the files needed for the task
2. keep unrelated refactors out
3. provide a git commit for the task
4. include runtime evidence in the commit message or an attached note referenced by the commit

### Required runtime evidence

A sub-task is not considered fully verifiable without evidence of execution.
At minimum include:

- project run command used
- whether project launched successfully
- any compiler/parser/runtime errors encountered
- if successful, a concise description of observed behavior

Preferred evidence forms:

- terminal output from headless checks or project launch
- Godot parser/load output
- screenshots if available
- short observation summary

## Validation Method

The validator checks each sub-task in this order:

1. **Scope check** via `git diff --stat` and `git diff`
   - only expected files changed
   - no unrelated churn
2. **Requirement mapping**
   - every changed file maps to the assigned sub-task
3. **Runtime evidence check**
   - execution evidence is present
   - evidence matches claimed completion
4. **Acceptance criteria check**
   - all criteria satisfied
5. **Regression sanity check**
   - baseline features still conceptually intact

A sub-task result must be recorded as one of:

- **PASS**
- **FAIL**
- **PASS WITH NOTES**

## Sub-task Breakdown

---

## Task 0 - Project boot and validation harness

### Objective

Establish the planning/validation docs and define the execution contract.

### Expected outputs

- `docs/plan-and-verify.md`
- `docs/validation/task-checklist.md`

### Acceptance criteria

- planner/validator workflow is documented
- validation method is explicit
- remaining tasks are broken down clearly

### Validator checks

- docs exist
- docs are internally consistent
- tasks are actionable, not vague

---

## Task 1 - Battlefield terrain and obstacles

### Objective

Turn the current battle scene into an actual battlefield with visible terrain and navigationally meaningful obstacles.

### Expected outputs

Possible changed areas include:

- `game/test/scenes/battle_root.tscn`
- new terrain/obstacle helper scenes/resources if needed
- small script support only if required

### Acceptance criteria

- battle scene visually communicates traversable area vs blocked area
- there are multiple obstacles that force route changes
- selected units moving to a point must route around obstacles instead of trying to walk straight through them
- scene remains loadable in Godot

### Notes

For this demo, temporary/simple visuals are acceptable. Gray boxes and colored ground are fine.

### Validator checks

- inspect diff for obstacle/nav related changes
- verify pathing setup is not fake visual-only obstruction
- verify no unnecessary system-wide refactor was introduced

---

## Task 2 - Temporary troop selection UI and flow into battle

### Objective

Create a simple pre-battle interface where the player can choose a temporary roster and then enter the battle scene.

### Expected outputs

Possible changed areas include:

- `game/test/scenes/main.tscn`
- new UI scene(s)
- flow/control script(s)
- battle spawn/setup wiring

### Acceptance criteria

- when opening the project, player can interact with a temporary troop-selection interface
- player can choose from at least 2 unit/troop options
- player can confirm and enter battle
- chosen selection affects what spawns or is available in battle
- flow works end-to-end without manual scene switching in the editor

### Notes

This UI is intentionally temporary. Function beats polish.

### Validator checks

- diff is focused on flow/UI/spawn plumbing
- launch path starts from main entry and reaches battle
- chosen options are actually consumed, not purely decorative

---

## Task 3 - Controlled movement and multi-unit command behavior

### Objective

Make battlefield control reliable enough for demo use.

### Expected outputs

Possible changed areas include:

- unit movement scripts
- selection handling
- battle command logic

### Acceptance criteria

- player can select controllable units
- issuing move commands consistently moves selected units
- multiple selected units do not all stack on the exact same destination point
- movement around obstacles still works after improvements

### Notes

A simple formation offset or slot assignment is enough.

### Validator checks

- diff shows command/movement logic only
- no fake acceptance by disabling selection or simplifying to one unit
- movement behavior improved relative to baseline

---

## Task 4 - Pair combat / melee engagement

### Objective

Implement a simple combat loop where opposing units can engage and fight in pairs.

### Expected outputs

Possible changed areas include:

- unit scripts
- battle coordination scripts
- optional simple combat data/config
- optional temporary HUD feedback

### Acceptance criteria

- opposing units can detect valid enemies
- units can move into engagement range and attack
- combat produces visible state change such as HP loss, death, or removal
- pairwise engagement behavior exists (units do not all mindlessly overlap a single point with no pairing logic)
- the battle can visibly progress because of combat

### Notes

Simple is fine:

- nearest-target selection
- one-target-at-a-time lock
- fixed damage interval
- basic death handling

No need for a deep combat system.

### Validator checks

- diff contains actual combat logic, not animation-only stubs
- runtime evidence shows combat can resolve encounters
- state transitions (idle/move/fight/dead) are coherent enough for demo use

---

## Task 5 - Demo integration pass

### Objective

Make the whole loop coherent from entry UI to battlefield combat.

### Expected outputs

- integrated playable flow
- any small glue fixes required across previous tasks
- optional short README usage update

### Acceptance criteria

- launch project -> select troops -> enter battle -> move units -> units fight enemies
- no required editor-only manual setup to demonstrate the loop
- no blocker errors in normal launch

### Validator checks

- diff is integration-focused, not a stealth rewrite
- runtime evidence covers the full loop
- known limitations are explicitly stated

---

## Definition of Done for the Demo

The demo is done when a fresh validator can reasonably verify:

1. project launches
2. troop selection screen appears
3. player enters battle from that screen
4. player can select and command units to move
5. terrain/obstacles change navigation behavior
6. units engage enemies and resolve combat visibly

## Validation Record Template

For each task, record:

- Task ID
- Commit SHA
- Diff summary
- Runtime evidence summary
- Result: PASS / FAIL / PASS WITH NOTES
- Notes / follow-up

See `docs/validation/task-checklist.md`.
