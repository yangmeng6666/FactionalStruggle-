#!/usr/bin/env python3
import re
import subprocess
import sys
from pathlib import Path

REQUIRED_PATTERNS = [
    r"^Runtime evidence:",
    r"^\s*[-*]?\s*Command:",
]

RESULT_HINT_PATTERNS = [
    r"^\s*[-*]?\s*Result:",
    r"^\s*[-*]?\s*Observed",
    r"^\s*[-*]?\s*Project loads",
    r"^\s*[-*]?\s*Project imports",
    r"^\s*[-*]?\s*Main scene loads",
]


def get_commit_message(repo: Path, rev: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), "log", "-1", "--format=%B", rev],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout


def main() -> int:
    repo = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    rev = sys.argv[2] if len(sys.argv) > 2 else "HEAD"

    try:
        message = get_commit_message(repo, rev)
    except subprocess.CalledProcessError as exc:
        print(f"FAIL: unable to read commit message for {rev}: {exc}")
        return 2

    missing = []
    for pattern in REQUIRED_PATTERNS:
        if not re.search(pattern, message, flags=re.MULTILINE):
            missing.append(pattern)

    has_result_hint = any(re.search(pattern, message, flags=re.MULTILINE) for pattern in RESULT_HINT_PATTERNS)

    if missing:
        print("FAIL: commit message missing required runtime evidence markers:")
        for pattern in missing:
            print(f"  - {pattern}")
        return 1

    if not has_result_hint:
        print("FAIL: commit message missing a result/observation section")
        return 1

    print(f"PASS: commit {rev} includes runtime evidence markers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
