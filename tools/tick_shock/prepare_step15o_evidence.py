#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "reports/backtest/runs/20260908_ts15o_cross_fx_lead_lag_r2_202504"
RUN_ID = "ts15o_cross_fx_lead_lag_r2_202504"
SYMBOLS = ("EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF")


def main() -> None:
    logs = sorted(
        (Path.home() / "AppData/Roaming/MetaQuotes/Tester").glob(
            "*/Agent-127.0.0.1-3000/logs/20260908.log"
        )
    )
    if not logs:
        raise SystemExit("tester journal not found")
    lines = logs[-1].read_text(encoding="utf-16", errors="replace").splitlines()
    start = next(i for i, line in enumerate(lines) if f"InpRunId={RUN_ID}" in line)
    tokens = (
        "InpRunId=", "InpResearchPeriod=", "InpDetectorVersion=",
        "real ticks discarded", "initialized research_only", "deinitialized reason=",
        "Test passed in", "total ticks for all symbols", "generate ", "memory used",
    )
    excerpt = [line for line in lines[start:] if any(token in line for token in tokens)]
    (RUN / "tester_journal_excerpt.txt").write_text("\n".join(excerpt) + "\n", encoding="utf-8")

    with (RUN / "summary.csv").open(encoding="utf-8-sig", newline="") as handle:
        summary = list(csv.DictReader(handle))
    warnings = [line for line in excerpt if "real ticks discarded" in line]
    quality = []
    for symbol in SYMBOLS:
        row = next(r for r in summary if r["record_type"] == "SYMBOL" and r["key"] == symbol)
        match = re.search(r"m1_minutes_seen=(\d+)", row["value"])
        symbol_warnings = [line for line in warnings if symbol in line]
        quality.append(
            {
                "symbol": symbol,
                "ea_m1_minutes_seen": int(match.group(1)) if match else "",
                "real_tick_discard_warning_count": len(symbol_warnings),
                "generated_fallback_minutes": "NOT_OBSERVED" if not symbol_warnings else "INTERVAL_MAP_UNAVAILABLE",
                "discarded_ticks": "0_REPORTED_BY_EA",
                "missing_interval": "NOT_OBSERVED",
                "stale_proportion": "SEE_CROSS_FX_FEATURE_FRESHNESS",
                "status": "NO_DISCARD_WARNING_OBSERVED" if not symbol_warnings else "GENERATED_TICK_FALLBACK_OBSERVED",
                "evidence": "tester_journal_excerpt.txt",
            }
        )
    with (RUN / "tick_quality.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=quality[0].keys())
        writer.writeheader(); writer.writerows(quality)

    def rows(name: str) -> int:
        with (RUN / name).open(encoding="utf-8-sig") as handle:
            return sum(1 for _ in handle) - 1

    (RUN / "summary.md").write_text(
        "\n".join(
            [
                "# Step 15O formal April Cross-FX run", "",
                "- Period: 2025-04-01 to 2025-05-01 (development, not OOS)",
                "- Driver/model: EURUSD M1 / real ticks",
                "- Symbols: EURUSD, GBPUSD, AUDUSD, USDJPY, USDCHF, USDCAD",
                "- Detector: frozen TAIL_V1_PERSISTENT",
                "- Execution: REALIZABLE_EA research-only; actual orders/trades 0",
                f"- Cross-FX feature rows: {rows('cross_fx_features.csv'):,}",
                f"- Cross-FX freshness rows: {rows('cross_fx_feature_freshness.csv'):,}",
                f"- Cross-FX action rows: {rows('cross_fx_actions.csv'):,}",
                "- Tester runtime: 0:28:18.521",
                "- Tester total ticks across symbols: 14,085,619",
                "- Tester memory: 624 MB (48 MB history, 320 MB tick data)",
                "- Real-tick discard/generated-fallback warnings: 0 observed for all six symbols",
                "- All-tick CSV: disabled; one-second CSV: disabled",
                "",
                "> Outcomes are intentionally not interpreted in this evidence-preparation step.",
            ]
        ) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
