#!/usr/bin/env python3
import argparse
import re
import subprocess
import sys
from pathlib import Path

PROTECTED_PREFIXES = [
    "docs/harness/",
    "docs/validation/",
]

TASK_SCOPE_HINTS = {
    "T1": ["game/test/scenes/battle_root.tscn", "game/test/scripts/battle/"],
    "T2": ["game/test/scenes/main.tscn", "game/test/scenes/troop_selection.tscn", "game/test/scripts/core/", "game/test/scripts/ui/", "game/test/scripts/battle/"],
    "T3": ["game/test/scripts/battle/", "game/test/scripts/units/", "game/test/scripts/ui/"],
    "T4": ["game/test/scripts/battle/", "game/test/scripts/units/", "game/test/scripts/core/"],
    "T5": ["game/test/", "README.md"],
}


def git_lines(repo: Path, *args: str):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, check=True)
    return result.stdout.splitlines()


def get_changed_files(repo: Path, rev: str):
    return [line for line in git_lines(repo, "diff-tree", "--no-commit-id", "--name-only", "-r", rev) if line.strip()]


def parse_status_board(path: Path):
    text = path.read_text(encoding="utf-8")
    rows = {}
    for line in text.splitlines():
        if not line.startswith("| T"):
            continue
        parts = [part.strip() for part in line.strip("|").split("|")]
        if len(parts) < 6:
            continue
        rows[parts[0]] = {
            "status": parts[1],
            "owner": parts[2],
            "blocked_by": parts[3],
            "latest_commit": parts[4],
            "notes": parts[5],
        }
    return rows


def parse_dependency_graph(path: Path):
    text = path.read_text(encoding="utf-8")
    deps = {}
    for line in text.splitlines():
        match = re.match(r"- `?(T\d+)`? -> (.*)", line.strip())
        if not match:
            continue
        task, rhs = match.groups()
        found = re.findall(r"T\d+", rhs)
        deps[task] = found
    return deps


def check_scope(task_id: str, changed_files):
    hints = TASK_SCOPE_HINTS.get(task_id, [])
    unexpected = []
    for changed in changed_files:
        if changed == "docs/tasks/status-board.md":
            continue
        if any(changed == hint or changed.startswith(hint) for hint in hints):
            continue
        unexpected.append(changed)
    return unexpected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", nargs="?", default=".")
    parser.add_argument("--task", required=True)
    parser.add_argument("--rev", default="HEAD")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    task_id = args.task
    rev = args.rev

    status_board = parse_status_board(repo / "docs/tasks/status-board.md")
    dependency_graph = parse_dependency_graph(repo / "docs/tasks/dependency-graph.md")
    changed_files = get_changed_files(repo, rev)

    failures = []
    warnings = []

    if task_id not in status_board:
        failures.append(f"task {task_id} missing from status board")
    if task_id not in dependency_graph:
        warnings.append(f"task {task_id} missing from dependency graph parse")

    for changed in changed_files:
        if any(changed.startswith(prefix) for prefix in PROTECTED_PREFIXES):
            failures.append(f"protected docs modified: {changed}")

    unexpected = check_scope(task_id, changed_files)
    if unexpected:
        warnings.append(f"files outside task scope hints: {', '.join(unexpected)}")

    if failures:
        print("FAIL: task rule violations found:")
        for item in failures:
            print(f"  - {item}")
        if warnings:
            print("WARN:")
            for item in warnings:
                print(f"  - {item}")
        return 1

    if warnings:
        print("PASS WITH WARNINGS:")
        for item in warnings:
            print(f"  - {item}")
        return 0

    print(f"PASS: task rules OK for {task_id} at {rev}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
