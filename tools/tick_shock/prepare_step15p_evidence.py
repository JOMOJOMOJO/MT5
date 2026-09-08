#!/usr/bin/env python3
from __future__ import annotations

import csv
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SYMBOLS = ("EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    run = args.run_dir.resolve()
    run_id = args.run_id
    logs = sorted((Path.home() / "AppData/Roaming/MetaQuotes/Tester").glob("*/Agent-127.0.0.1-3000/logs/20260908.log"))
    if not logs:
        raise SystemExit("tester journal not found")
    lines = logs[-1].read_text(encoding="utf-16", errors="replace").splitlines()
    starts = [i for i, line in enumerate(lines) if f"InpRunId={run_id}" in line]
    if not starts:
        raise SystemExit("run id missing from tester journal")
    tokens = ("InpRunId=", "InpResearchPeriod=", "InpDetectorVersion=", "real ticks discarded", "initialized research_only", "deinitialized reason=", "Test passed in", "total ticks for all symbols", "memory used")
    excerpt = [line for line in lines[starts[-1] :] if any(token in line for token in tokens)]
    (run / "tester_journal_excerpt.txt").write_text("\n".join(excerpt) + "\n", encoding="utf-8")
    with (run / "summary.csv").open(encoding="utf-8-sig", newline="") as handle:
        summary = list(csv.DictReader(handle))
    warnings = [line for line in excerpt if "real ticks discarded" in line]
    quality = []
    for symbol in SYMBOLS:
        row = next(r for r in summary if r["record_type"] == "SYMBOL" and r["key"] == symbol)
        match = re.search(r"m1_minutes_seen=(\d+)", row["value"])
        symbol_warnings = [line for line in warnings if symbol in line]
        quality.append({"symbol": symbol, "ea_m1_minutes_seen": int(match.group(1)) if match else "", "real_tick_discard_warning_count": len(symbol_warnings), "generated_fallback_minutes": "NOT_OBSERVED" if not symbol_warnings else "INTERVAL_MAP_UNAVAILABLE", "status": "NO_DISCARD_WARNING_OBSERVED" if not symbol_warnings else "GENERATED_TICK_FALLBACK_OBSERVED", "evidence": "tester_journal_excerpt.txt"})
    with (run / "tick_quality.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=quality[0].keys());writer.writeheader();writer.writerows(quality)


if __name__ == "__main__":
    main()
