#!/usr/bin/env python3
import argparse
from pathlib import Path

TEMPLATE = """# Review Record\n\n- Task ID: {task}\n- Commit SHA: {rev}\n- Verdict: {verdict}\n- Validator: {validator}\n\n## Summary\n\n{summary}\n\n## Scope\n\n{scope}\n\n## Runtime Evidence\n\n{runtime}\n\n## Acceptance\n\n{acceptance}\n\n## Performance\n\n{performance}\n\n## Notes\n\n{notes}\n"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", nargs="?", default=".")
    parser.add_argument("--task", required=True)
    parser.add_argument("--rev", required=True)
    parser.add_argument("--verdict", required=True)
    parser.add_argument("--validator", default="validator")
    parser.add_argument("--summary", default="")
    parser.add_argument("--scope", default="")
    parser.add_argument("--runtime", default="")
    parser.add_argument("--acceptance", default="")
    parser.add_argument("--performance", default="")
    parser.add_argument("--notes", default="")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    out_dir = repo / "docs" / "validation" / "records"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{args.task}-{args.rev}.md"

    content = TEMPLATE.format(
        task=args.task,
        rev=args.rev,
        verdict=args.verdict,
        validator=args.validator,
        summary=args.summary or "(fill me)",
        scope=args.scope or "(fill me)",
        runtime=args.runtime or "(fill me)",
        acceptance=args.acceptance or "(fill me)",
        performance=args.performance or "(fill me)",
        notes=args.notes or "(fill me)",
    )
    out_path.write_text(content, encoding="utf-8")
    print(f"WROTE: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
