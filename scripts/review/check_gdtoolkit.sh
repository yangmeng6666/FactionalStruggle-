#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
PROJECT_PATH="$REPO_ROOT/game/test"
VENV_BIN="$REPO_ROOT/.venv-review/bin"

if [[ -x "$VENV_BIN/gdlint" && -x "$VENV_BIN/gdformat" ]]; then
  "$VENV_BIN/gdlint" "$PROJECT_PATH"
  "$VENV_BIN/gdformat" --check "$PROJECT_PATH"
  exit 0
fi

if ! command -v gdlint >/dev/null 2>&1; then
  echo "SKIP: gdlint not installed"
  exit 0
fi

if ! command -v gdformat >/dev/null 2>&1; then
  echo "SKIP: gdformat not installed"
  exit 0
fi

gdlint "$PROJECT_PATH"
gdformat --check "$PROJECT_PATH"
