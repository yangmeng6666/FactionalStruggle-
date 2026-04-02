#!/usr/bin/env python3
import re
import sys
from pathlib import Path

HOT_FUNCTIONS = ["_process", "_physics_process"]
FORBIDDEN_IN_HOT = ["get_nodes_in_group", "find_child", "print("]
GD_SUFFIX = ".gd"

FUNC_RE = re.compile(r"^func\s+([A-Za-z0-9_]+)\s*\(")
INDENT_RE = re.compile(r"^(\s*)")


def iter_gd_files(root: Path):
    for path in root.rglob(f"*{GD_SUFFIX}"):
        yield path


def scan_file(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    issues = []

    current_func = None
    current_indent = None

    for lineno, line in enumerate(lines, start=1):
        match = FUNC_RE.match(line)
        if match:
            current_func = match.group(1)
            current_indent = len(INDENT_RE.match(line).group(1))
            continue

        if current_func is not None and line.strip():
            indent = len(INDENT_RE.match(line).group(1))
            if indent <= current_indent and not line.lstrip().startswith("#"):
                current_func = None
                current_indent = None

        if current_func in HOT_FUNCTIONS:
            for token in FORBIDDEN_IN_HOT:
                if token in line:
                    issues.append((lineno, current_func, token, line.strip()))

    return issues


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    gd_root = root / "game" / "test"
    if not gd_root.exists():
        gd_root = root

    total_issues = []
    for path in iter_gd_files(gd_root):
        issues = scan_file(path)
        for issue in issues:
            total_issues.append((path, *issue))

    if total_issues:
        print("FAIL: Godot hot-path rule violations found:")
        for path, lineno, func_name, token, snippet in total_issues:
            print(f"  - {path}:{lineno} in {func_name}: forbidden token '{token}' -> {snippet}")
        return 1

    print("PASS: no hot-path Godot rule violations found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
