#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path


def run_step(name, cmd, cwd):
    print(f"==> {name}")
    result = subprocess.run(cmd, cwd=cwd)
    if result.returncode != 0:
        print(f"FAIL: {name}")
        return result.returncode
    print(f"PASS: {name}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", nargs="?", default=".")
    parser.add_argument("--task", required=True)
    parser.add_argument("--rev", default="HEAD")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()

    steps = [
        ("task rules", [sys.executable, "scripts/review/check_task_rules.py", str(repo), "--task", args.task, "--rev", args.rev]),
        ("godot rules", [sys.executable, "scripts/review/check_godot_rules.py", str(repo)]),
        ("gdtoolkit", ["bash", "scripts/review/check_gdtoolkit.sh", str(repo)]),
        ("commit evidence", [sys.executable, "scripts/review/check_commit_evidence.py", str(repo), args.rev]),
        ("godot import", ["bash", "scripts/review/run_godot_import.sh", str(repo)]),
    ]

    print(f"Task: {args.task} | Rev: {args.rev}")

    for name, cmd in steps:
        code = run_step(name, cmd, cwd=repo)
        if code != 0:
            return code

    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
