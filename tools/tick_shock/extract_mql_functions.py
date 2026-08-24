#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
import subprocess
from pathlib import Path

FUNCTION_RE = re.compile(
    r"^[ \t]*(?!if\b|for\b|while\b|switch\b)"
    r"[A-Za-z_][A-Za-z0-9_]*[ \t*&]+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)[ \t]*"
    r"\((?P<arguments>[^;{}]*?)\)\s*(?:const\s*)?\{",
    re.MULTILINE | re.DOTALL,
)


def source_paths(root: Path) -> list[str]:
    paths = [
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",
        "mql/Include/TickShockStateMachine.mqh",
        "mql/Include/TickShockResearchExecution.mqh",
        "mql/Experts/tests/ExpectedValue_TickShock_ResearchReachabilityHarness.mq5",
        "mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5",
    ]
    paths.extend(path.relative_to(root).as_posix() for path in sorted((root / "mql/Include/TickShock").glob("*.mqh")))
    return paths


def read_source(root: Path, path: str, revision: str | None) -> str:
    if revision:
        return subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=root).decode("utf-8-sig")
    return (root / path).read_text(encoding="utf-8-sig")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--revision")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.repo_root.resolve()
    rows: list[dict[str, str | int]] = []
    for path in source_paths(root):
        try:
            text = read_source(root, path, args.revision)
        except subprocess.CalledProcessError:
            continue
        for match in FUNCTION_RE.finditer(text):
            if match.group("name") in {"if", "for", "while", "switch"}:
                continue
            rows.append({
                "path": path,
                "line": text.count("\n", 0, match.start()) + 1,
                "function": match.group("name"),
                "arguments": " ".join(match.group("arguments").split()),
            })
    if args.output:
        output = args.output if args.output.is_absolute() else root / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=("path", "line", "function", "arguments"))
            writer.writeheader(); writer.writerows(rows)
    print(f"functions={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
