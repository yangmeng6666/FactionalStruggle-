# Task T2 - Troop Selection and Battle Entry

## Objective

Create a simple pre-battle interface where the player can choose a temporary roster and then enter the battle scene.

## Read before implementing

- `docs/harness/executor-start.md`
- `game/test/scenes/main.tscn`
- any directly referenced flow/setup files you must touch

## Expected outputs

Possible changed areas include:

- `game/test/scenes/main.tscn`
- new UI scene(s)
- flow/control script(s)
- battle spawn/setup wiring

## Acceptance criteria

- when opening the project, player can interact with a temporary troop-selection interface
- player can choose from at least 2 unit/troop options
- player can confirm and enter battle
- chosen selection affects what spawns or is available in battle
- flow works end-to-end without manual scene switching in the editor

## Submission requirements

Include runtime evidence showing the flow from launch to battle entry and demonstrating that selected choices affect battle setup.

## Validator focus

- selection affects actual spawn/setup
- diff stays focused on UI/flow/spawn plumbing
