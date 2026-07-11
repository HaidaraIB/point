#!/usr/bin/env python3
"""Audit hardcoded text foreground colors that break dark mode."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib" / "View"

PATTERNS = [
    re.compile(r"color:\s*AppColors\.primary\b"),
    re.compile(r"foregroundColor:\s*AppColors\.primary\b"),
    re.compile(r"fontColor:\s*AppColors\.primary\b"),
    re.compile(r"color:\s*Colors\.black\d*\b"),
    re.compile(r"color:\s*Colors\.black\b"),
    re.compile(r"color:\s*Colors\.grey\b(?!\.)"),
    re.compile(r"color:\s*Colors\.grey\.shade[56789]\d*\b"),
]

SKIP_LINE_MARKERS = (
    "backgroundColor:",
    "borderColor:",
    "BorderSide(",
    "Border.all(",
    "boxShadow:",
    "gradient:",
    "withValues(alpha:",
    "activeThumbColor:",
    "selectedColor:",
    "fillColor:",
)


def is_text_foreground_issue(line: str) -> bool:
    if any(marker in line for marker in SKIP_LINE_MARKERS):
        return False
    return any(p.search(line) for p in PATTERNS)


def main() -> None:
    issues: list[tuple[str, int, str]] = []
    for path in sorted(ROOT.rglob("*.dart")):
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if is_text_foreground_issue(line):
                issues.append((str(path.relative_to(ROOT.parent.parent)), i, line.strip()))

    if not issues:
        print("No text-foreground violations found.")
        return

    print(f"Found {len(issues)} potential violations:\n")
    for file, line_no, content in issues:
        print(f"{file}:{line_no}: {content}")


if __name__ == "__main__":
    main()
