#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
PROJECT_PATH="$REPO_ROOT/game/test"
GODOT_BIN="${GODOT_BIN:-/root/tools/godot/4.6.1/extracted/Godot_v4.6.1-stable_linux.x86_64}"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "FAIL: Godot binary not found or not executable: $GODOT_BIN" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "FAIL: project path not found: $PROJECT_PATH" >&2
  exit 2
fi

GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --path "$PROJECT_PATH" --import
