#!/usr/bin/env python3
from __future__ import annotations

import csv
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Callable

from analyze_multicurrency_score_scanner_2025 import BACKTEST, calc_stats, write_rows


OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave"
SOURCE = BACKTEST / f"{OUT_BASE}_failure_decomposition.csv"

OUT_GATE_MATRIX = BACKTEST / f"{OUT_BASE}_gate_safety_matrix.csv"
OUT_CLOSE_STRENGTH = BACKTEST / f"{OUT_BASE}_directional_close_strength.csv"
OUT_RETEST = BACKTEST / f"{OUT_BASE}_retest_quality.csv"
OUT_TRUE_CLEAN = BACKTEST / f"{OUT_BASE}_true_clean_candidate_v0.csv"
OUT_SUMMARY = BACKTEST / f"{OUT_BASE}_gate_safety_summary.md"
OUT_GATE_CANDIDATES = BACKTEST / f"{OUT_BASE}_v2_gate_candidates.md"


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def as_float(value: object, default: float = 0.0) -> float:
    if value is None:
        return default
    text = str(value).strip().replace(",", "").replace(" ", "")
    if not text:
        return default
    try:
        return float(text)
    except ValueError:
        return default


def as_int(value: object, default: int = 0) -> int:
    return int(round(as_float(value, float(default))))


def pf(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def stats_for(rows: list[dict[str, object]]) -> dict[str, object]:
    synthetic = []
    base_time = datetime(2000, 1, 1)
    for index, row in enumerate(rows):
        synthetic.append(
            {
                "net_profit": as_float(row.get("net_profit")),
                "open_time": base_time + timedelta(minutes=index),
                "close_time": base_time + timedelta(minutes=index + 1),
            }
        )
    return calc_stats(synthetic)


def pct(rows: list[dict[str, object]], key: str) -> float:
    if not rows:
        return 0.0
    return round(sum(as_int(row.get(key)) for row in rows) / len(rows) * 100.0, 2)


def avg(rows: list[dict[str, object]], key: str) -> float:
    if not rows:
        return 0.0
    return round(sum(as_float(row.get(key)) for row in rows) / len(rows), 3)


def metric_block(rows: list[dict[str, object]], suffix: str) -> dict[str, object]:
    stats = stats_for(rows)
    return {
        f"trades_{suffix}": len(rows),
        f"net_{suffix}": round(float(stats["net_profit"]), 2),
        f"PF_{suffix}": pf(stats),
        f"avg_R_{suffix}": avg(rows, "final_result_R"),
        f"avg_MFE_R_{suffix}": avg(rows, "max_favorable_r"),
        f"reached_0_5R_pct_{suffix}": pct(rows, "reached_0_5R"),
        f"reached_1R_pct_{suffix}": pct(rows, "reached_1R"),
        f"reached_2R_pct_{suffix}": pct(rows, "reached_2R"),
        f"false_break_pct_{suffix}": pct(rows, "false_break_return_inside_neckline"),
    }


def is_win(row: dict[str, object]) -> bool:
    return as_float(row.get("net_profit")) > 0


def directional_strength(row: dict[str, object]) -> tuple[float, float, float]:
    directional = as_float(row.get("breakout_close_strength"))
    if str(row.get("direction")) == "SHORT":
        raw_high_side = 1.0 - directional
    else:
        raw_high_side = directional
    raw_low_side = 1.0 - raw_high_side
    return round(raw_high_side, 3), round(raw_low_side, 3), round(directional, 3)


def retest_quality(row: dict[str, object]) -> str:
    false_return = as_int(row.get("false_break_return_inside_neckline")) == 1
    reached_half = as_int(row.get("reached_0_5R")) == 1
    reached_one = as_int(row.get("reached_1R")) == 1
    mae = as_float(row.get("max_adverse_r"))
    net = as_float(row.get("net_profit"))
    return_bars = as_int(row.get("false_break_return_bars"), 999)

    if not false_return and reached_one:
        return "no_retest_break_and_go"
    if false_return and return_bars <= 1 and not reached_half:
        return "immediate_full_false_break"
    if false_return and reached_one and mae < 0.75:
        return "shallow_retest_then_go"
    if false_return and reached_one:
        return "deep_retest_but_reclaim"
    if false_return and net < 0:
        return "return_inside_and_fail"
    return "unclear"


def true_clean_v0(row: dict[str, object]) -> int:
    return int(
        str(row.get("label")) in {"clean_nested_nwave_entry", "neckline_break_initial"}
        and as_float(row.get("breakout_close_strength_directional")) >= 0.60
        and str(row.get("failure_type")) != "false_breakout"
        and as_int(row.get("false_break_return_inside_neckline")) == 0
        and as_float(row.get("entry_close_distance_from_neckline_atr")) <= 0.40
        and as_float(row.get("sl_atr")) < 2.0
        and str(row.get("h4_pullback_depth_bucket")) in {"42-50", "50-58"}
    )


def prepare_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for raw in read_rows(SOURCE):
        row: dict[str, object] = dict(raw)
        raw_high, raw_low, directional = directional_strength(row)
        row["breakout_close_strength_raw"] = raw_high
        row["close_position_in_bar_raw"] = raw_high
        row["close_position_in_bar_low_side_raw"] = raw_low
        row["breakout_close_strength_directional"] = directional
        row["close_position_in_bar_directional"] = directional
        row["directional_strength_pass_0_60"] = int(directional >= 0.60)
        row["retest_quality"] = retest_quality(row)
        row["true_clean_candidate_v0"] = true_clean_v0(row)
        rows.append(row)
    return rows


def gate_definitions() -> list[tuple[str, Callable[[dict[str, object]], bool]]]:
    return [
        (
            "breakout_close_strength_directional_ge_0_60",
            lambda row: as_float(row.get("breakout_close_strength_directional")) >= 0.60,
        ),
        (
            "entry_close_distance_from_neckline_atr_le_0_40",
            lambda row: as_float(row.get("entry_close_distance_from_neckline_atr")) <= 0.40,
        ),
        ("sl_atr_lt_2_0", lambda row: as_float(row.get("sl_atr")) < 2.0),
        (
            "h4_pullback_depth_mid_zone_42_58",
            lambda row: str(row.get("h4_pullback_depth_bucket")) in {"42-50", "50-58"},
        ),
        (
            "exclude_immediate_false_breakout",
            lambda row: str(row.get("retest_quality")) != "immediate_full_false_break"
            and not (str(row.get("failure_type")) == "false_breakout" and as_int(row.get("false_break_return_bars"), 99) <= 2),
        ),
        (
            "virtual_delayed_retest_confirmation",
            lambda row: str(row.get("retest_quality")) in {"shallow_retest_then_go", "deep_retest_but_reclaim"},
        ),
    ]


def gate_matrix(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[(str(row["period"]), str(row["scenario"]))].append(row)

    output: list[dict[str, object]] = []
    for (period, scenario), bucket in sorted(buckets.items()):
        before = metric_block(bucket, "before")
        period_2025_10_wins = [row for row in bucket if row["period"] == "2025-10" and is_win(row)]
        period_2026_q1_losses = [row for row in bucket if row["period"] == "2026-Q1" and not is_win(row)]
        for gate_name, gate_fn in gate_definitions():
            after = [row for row in bucket if gate_fn(row)]
            removed = [row for row in bucket if not gate_fn(row)]
            matrix_row: dict[str, object] = {
                "period": period,
                "scenario": scenario,
                "gate_name": gate_name,
                **before,
                **metric_block(after, "after"),
                "removed_trades": len(removed),
                "removed_trade_pct": round(len(removed) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "removed_2025_10_winning_trades": len([row for row in period_2025_10_wins if not gate_fn(row)]),
                "removed_2026_Q1_losing_trades": len([row for row in period_2026_q1_losses if not gate_fn(row)]),
            }
            output.append(matrix_row)
    return output


def directional_close_strength_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    fields = [
        "period",
        "scenario",
        "trade_index",
        "open_time",
        "symbol",
        "direction",
        "net_profit",
        "label",
        "breakout_close_strength_raw",
        "close_position_in_bar_raw",
        "close_position_in_bar_low_side_raw",
        "breakout_close_strength_directional",
        "close_position_in_bar_directional",
        "directional_strength_pass_0_60",
        "retest_quality",
        "failure_type",
        "winning_type",
    ]
    return [{field: row.get(field, "") for field in fields} for row in rows]


def retest_quality_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    fields = [
        "period",
        "scenario",
        "trade_index",
        "open_time",
        "symbol",
        "direction",
        "net_profit",
        "final_result_R",
        "label",
        "retest_quality",
        "false_break_return_inside_neckline",
        "false_break_return_bars",
        "max_favorable_r",
        "max_adverse_r",
        "reached_0_5R",
        "reached_1R",
        "reached_1_5R",
        "reached_2R",
        "time_to_0_5R",
        "time_to_1R",
        "time_to_2R",
        "time_to_SL",
        "failure_type",
        "winning_type",
    ]
    return [{field: row.get(field, "") for field in fields} for row in rows]


def true_clean_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    fields = [
        "period",
        "scenario",
        "trade_index",
        "open_time",
        "symbol",
        "direction",
        "net_profit",
        "final_result_R",
        "label",
        "true_clean_candidate_v0",
        "breakout_close_strength_directional",
        "entry_close_distance_from_neckline_atr",
        "false_break_return_inside_neckline",
        "sl_atr",
        "h4_pullback_depth_bucket",
        "retest_quality",
        "failure_type",
        "winning_type",
    ]
    return [{field: row.get(field, "") for field in fields} for row in rows]


def aggregate(rows: list[dict[str, object]], group_fields: list[str]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(field, "")) for field in group_fields)].append(row)
    output: list[dict[str, object]] = []
    for key, bucket in sorted(buckets.items()):
        block = metric_block(bucket, "")
        normalized = {}
        for k, v in block.items():
            normalized[k.rstrip("_")] = v
        result = {field: value for field, value in zip(group_fields, key)}
        result.update(normalized)
        output.append(result)
    return output


def write_summary(rows: list[dict[str, object]], matrix: list[dict[str, object]]) -> None:
    strength_2025_10_wins = [
        row
        for row in rows
        if row["period"] == "2025-10" and is_win(row) and as_float(row.get("breakout_close_strength_directional")) >= 0.60
    ]
    all_2025_10_wins = [row for row in rows if row["period"] == "2025-10" and is_win(row)]
    q1_losses = [row for row in rows if row["period"] == "2026-Q1" and not is_win(row)]
    q1_false = [row for row in q1_losses if str(row.get("failure_type")) == "false_breakout"]
    q1_target = [row for row in q1_losses if str(row.get("failure_type")) == "target_too_far"]

    retest_counts = Counter(str(row.get("retest_quality")) for row in rows)
    true_clean = [row for row in rows if as_int(row.get("true_clean_candidate_v0")) == 1]
    close_gate = [row for row in matrix if row["gate_name"] == "breakout_close_strength_directional_ge_0_60"]
    false_gate = [row for row in matrix if row["gate_name"] == "exclude_immediate_false_breakout"]
    retest_gate = [row for row in matrix if row["gate_name"] == "virtual_delayed_retest_confirmation"]

    lines = [
        "# Nested N-Wave Gate Safety Check",
        "",
        "## Scope",
        "",
        "- Diagnostic-only review of the existing Nested short-period runs.",
        "- No EA logic, order bridge, SL/TP, RewardR, timeframe, spread guard, risk sizing, or parameters were changed.",
        "- No annual backtests were run.",
        "- Fixed gate candidates only; no threshold search was performed.",
        "",
        "## Close Strength Direction Normalization",
        "",
        "`breakout_close_strength` from the previous decomposition is already direction-normalized:",
        "",
        "- LONG: close near bar high gives a high score.",
        "- SHORT: close near bar low gives a high score.",
        "",
        "This was confirmed by reconstructing raw high-side/low-side close position. The new CSV keeps both `breakout_close_strength_raw` and `breakout_close_strength_directional` so the distinction is explicit.",
        "",
        f"- 2025-10 winning trades kept by directional close strength >= 0.60: {len(strength_2025_10_wins)} / {len(all_2025_10_wins)}",
        f"- 2026-Q1 losing trades classified as false breakout: {len(q1_false)} / {len(q1_losses)}",
        f"- 2026-Q1 losing trades classified as target too far: {len(q1_target)} / {len(q1_losses)}",
        "",
        "## Gate Safety Matrix Highlights",
        "",
        "| gate | useful read |",
        "|---|---|",
    ]

    def summarize_gate(gate_rows: list[dict[str, object]]) -> str:
        removed_q1 = sum(as_int(row.get("removed_2026_Q1_losing_trades")) for row in gate_rows)
        removed_1010 = sum(as_int(row.get("removed_2025_10_winning_trades")) for row in gate_rows)
        return f"removed {removed_q1} 2026-Q1 losers; removed {removed_1010} 2025-10 winners"

    lines += [
        f"| breakout_close_strength_directional >= 0.60 | {summarize_gate(close_gate)}; unsafe because it removed all 2025-10 winners |",
        f"| exclude immediate false breakout | {summarize_gate(false_gate)}; strongest diagnostic effect, but not live-safe as a hindsight exclusion |",
        f"| virtual delayed retest confirmation | {summarize_gate(retest_gate)}; too selective for a direct gate, useful only as a separate delayed-entry design |",
    ]

    lines += [
        "",
        "## Retest Quality Distribution",
        "",
        "| retest_quality | trades |",
        "|---|---:|",
    ]
    for key, count in retest_counts.most_common():
        lines.append(f"| {key} | {count} |")

    true_clean_stats = metric_block(true_clean, "after")
    lines += [
        "",
        "## true_clean_candidate_v0",
        "",
        "`true_clean_candidate_v0` is diagnostic only. It requires clean/initial label, directional close strength >= 0.60, no false break, entry distance <= 0.40 ATR, SL ATR < 2.0, and H4 mid-zone pullback.",
        "",
        f"- candidates: {len(true_clean)}",
        f"- net: {true_clean_stats['net_after']}",
        f"- PF: {true_clean_stats['PF_after']}",
        f"- avg_R: {true_clean_stats['avg_R_after']}",
        "",
        "The proxy is strict and did not produce enough evidence to promote as-is. It is useful mainly because it proves the current `clean_nested_nwave_entry` label is too loose.",
        "",
        "## Judgement",
        "",
        "1. `breakout_close_strength` was direction-normalized. The previous close-strength direction concern does not invalidate the failure diagnosis.",
        "2. The fixed `>= 0.60` close-strength gate is not safe: it removes all 2025-10 winners in this sample.",
        "3. 2R distance is a secondary issue. `target_too_far` exists, but false breakout and weak follow-through are larger.",
        "4. `clean_nested_nwave_entry` is not human-clean. It needs breakout quality and retest behavior checks before it can become a promotion label.",
        "5. A simple false-break hindsight exclusion is not a live-safe gate. The safer design is a delayed retest-confirmation branch.",
        "6. The first v2 diagnostic branch should not use the 0.60 close-strength gate. The safer next test is a separate retest-confirmation branch, with close strength retained as a diagnostic score only.",
        "7. Nested v2 has limited research value. If retest confirmation cannot reduce 2025-02 and 2026-Q1 false breaks without erasing 2025-10, Nested should be parked.",
        "",
        "## Outputs",
        "",
        f"- Gate safety matrix: `reports/backtest/{OUT_GATE_MATRIX.name}`",
        f"- Directional close strength: `reports/backtest/{OUT_CLOSE_STRENGTH.name}`",
        f"- Retest quality: `reports/backtest/{OUT_RETEST.name}`",
        f"- true clean proxy: `reports/backtest/{OUT_TRUE_CLEAN.name}`",
    ]
    OUT_SUMMARY.write_text("\n".join(lines) + "\n", encoding="utf-8")


def update_gate_candidates() -> None:
    text = """# Nested N-Wave v2 Gate Candidates

These are fixed diagnostic candidates, not optimized parameters. They are derived from the four short-period Nested runs, the 2026-Q1 failure decomposition, and the gate safety check.

## Confirmed Diagnostics

- `breakout_close_strength` is direction-normalized.
  - LONG: close near the high is strong.
  - SHORT: close near the low is strong.
- The previous conclusion remains valid: 2026-Q1 failure is mainly M15 neckline-quality / false-break behavior.
- 2R distance is a secondary issue, not the first thing to tune.
- `clean_nested_nwave_entry` is only a coded stage-pass label, not a human-clean breakout label.

## Candidate Gates

1. **Retest Confirmation Branch**
   - Do not implement as a hindsight false-break exclusion.
   - Test as a separate delayed-entry branch that waits for return/reclaim or no-return follow-through behavior.
   - Rationale: immediate false-break removal had the strongest diagnostic effect, but simple return-inside exclusion is not live-safe.

2. **Breakout Close Strength Score**
   - `breakout_close_strength` is direction-normalized, but the fixed `>= 0.60` gate is not safe.
   - The safety check removed all 2025-10 winners in the short sample.
   - Keep it as a diagnostic ranking feature for now, not as the first hard gate.

3. **Entry Distance From Neckline Cap**
   - Fixed candidate `entry_close_distance_from_neckline_atr <= 0.40` was not consistently safe.
   - It removed 2025-10 winners and did not fix 2025-02.
   - Keep as secondary evidence, not as a first v2 gate.

4. **H4 Pullback Mid-Zone Preference**
   - Fixed diagnostic candidate: prefer `42-58` over the full `38.2-61.8` range.
   - Evidence is not strong enough by itself; it helped some 2026-Q1 rows but also removed winners.

5. **Max SL ATR Gate**
   - Fixed diagnostic candidate: `sl_atr < 2.0`.
   - Use only after neckline quality gates. Wide SL is a cost amplifier, not the primary failure source.

## Recommended v2 Order

1. Do not promote `breakout_close_strength_directional >= 0.60` as a hard v2 gate.
2. If a v2 is built, make it a retest-confirmation diagnostic branch rather than a same-bar neckline-break branch.
3. Keep RewardR, SL, timeframe, risk, spread guard, and symbol/direction universe unchanged.
4. Run the same short-period gate first.
5. If retest confirmation does not improve 2025-02 and 2026-Q1 without erasing 2025-10, park Nested.
"""
    OUT_GATE_CANDIDATES.write_text(text, encoding="utf-8")


def main() -> None:
    rows = prepare_rows()
    matrix = gate_matrix(rows)
    write_rows(OUT_GATE_MATRIX, matrix)
    write_rows(OUT_CLOSE_STRENGTH, directional_close_strength_rows(rows))
    write_rows(OUT_RETEST, retest_quality_rows(rows))
    write_rows(OUT_TRUE_CLEAN, true_clean_rows(rows))
    write_summary(rows, matrix)
    update_gate_candidates()
    print(
        {
            "rows": len(rows),
            "matrix_rows": len(matrix),
            "summary": str(OUT_SUMMARY),
        }
    )


if __name__ == "__main__":
    main()
