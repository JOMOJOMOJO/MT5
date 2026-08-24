#!/usr/bin/env python3
"""Create provenance and tick-quality evidence for one completed Step 14R run."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import re
import tempfile
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def atomic_text(path: Path, value: str) -> None:
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def atomic_csv(path: Path, rows: list[dict[str, object]], fields: list[str]) -> None:
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def parse_map(value: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for token in value.split(";"):
        if "=" in token:
            key, raw = token.split("=", 1)
            result[key] = raw
    return result


def parse_set(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" in line and not line.lstrip().startswith(("#", ";")):
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def read_journal(path: Path) -> list[str]:
    raw = path.read_bytes()
    encoding = "utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8"
    return raw.decode(encoding, errors="replace").splitlines()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--tester-journal", required=True, type=Path)
    parser.add_argument("--terminal", required=True, type=Path)
    parser.add_argument("--metaeditor", required=True, type=Path)
    parser.add_argument("--broker-server", required=True)
    parser.add_argument("--run-command", required=True)
    args = parser.parse_args()
    repo = args.repo.resolve()
    run_dir = args.run_dir.resolve()
    sets = sorted(run_dir.glob("*.set"))
    if len(sets) != 1:
        raise ValueError(f"expected exactly one set, found {len(sets)}")
    config = parse_set(sets[0])
    run_id = config.get("InpRunId", "")
    if not run_id:
        raise ValueError("missing InpRunId")

    with (run_dir / "summary.csv").open(newline="", encoding="utf-8-sig") as handle:
        summary = list(csv.DictReader(handle))
    symbol_minutes: dict[str, int] = {}
    for row in summary:
        if row.get("record_type") == "SYMBOL":
            symbol_minutes[row["key"]] = int(parse_map(row.get("value", "")).get("m1_minutes_seen", "0"))

    journal_lines = read_journal(args.tester_journal)
    discard: dict[str, tuple[int, int]] = {}
    discard_pattern = re.compile(r"\b([A-Z]{6})\b.*real ticks discarded for (\d+) minutes of (\d+) total minute bars")
    for line in journal_lines:
        match = discard_pattern.search(line)
        if match:
            discard[match.group(1)] = (int(match.group(2)), int(match.group(3)))
    quality_rows: list[dict[str, object]] = []
    for symbol in config.get("InpSymbols", "").split(","):
        symbol = symbol.strip()
        fallback, total = discard.get(symbol, (0, 0))
        quality_rows.append({
            "symbol": symbol,
            "ea_m1_minutes_seen": symbol_minutes.get(symbol, 0),
            "tester_reported_total_minutes": total if total else "",
            "tester_reported_discarded_minutes": fallback if total else "",
            "tester_reported_fallback_rate_pct": f"{fallback * 100.0 / total:.4f}" if total else "0.0000",
            "status": "GENERATED_TICK_FALLBACK_OBSERVED" if total else "NO_DISCARD_WARNING_OBSERVED",
            "evidence": (
                f"tester journal: real ticks discarded for {fallback} minutes of {total} total minute bars"
                if total else "tester journal contains no discarded-real-ticks warning for this symbol"
            ),
        })
    atomic_csv(run_dir / "tick_quality.csv", quality_rows, list(quality_rows[0]))

    start = next((i for i, line in enumerate(journal_lines) if f"InpRunId={run_id}" in line), -1)
    excerpt: list[str] = []
    if start >= 0:
        start = max(0, start - 5)
        for line in journal_lines[start:]:
            excerpt.append(line)
            if "thread finished" in line and "ExpectedValue_MultiCurrency_TickShockResearch" in line:
                break
    if not excerpt:
        raise ValueError(f"run id not found in tester journal: {run_id}")
    atomic_text(run_dir / "tester_journal_excerpt.txt", f"Source: {args.tester_journal}\nExtracted for run: {run_id}\n\n" + "\n".join(excerpt) + "\n")
    atomic_text(run_dir / "run_command.txt", args.run_command.rstrip() + "\n")

    source_paths = [
        Path("mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"),
        Path("mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.ex5"),
        Path("mql/Include/TickShockResearchExecution.mqh"),
        Path("mql/Include/TickShockStateMachine.mqh"),
        *[path.relative_to(repo) for path in sorted((repo / "mql/Include/TickShock").glob("*.mqh"))],
    ]
    hashes = [
        f"source_commit|{config.get('InpSourceCommit', '')}",
        "terminal_build|6140",
        f"broker_server|{args.broker_server}",
    ]
    for relative in source_paths:
        absolute = repo / relative
        if not absolute.is_file():
            raise FileNotFoundError(absolute)
        hashes.append(f"{relative.as_posix()}|{sha256(absolute)}")
    hashes.append(f"{args.terminal.as_posix()}|{sha256(args.terminal)}")
    hashes.append(f"{args.metaeditor.as_posix()}|{sha256(args.metaeditor)}")
    for path in (sets[0], run_dir / "tester_config.ini", run_dir / "compile.log", run_dir / "tester_report.html", run_dir / "executed_EA.ex5"):
        if not path.is_file():
            raise FileNotFoundError(path)
        hashes.append(f"{path.name}|{sha256(path)}")
    atomic_text(run_dir / "source_hashes.txt", "\n".join(hashes) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
