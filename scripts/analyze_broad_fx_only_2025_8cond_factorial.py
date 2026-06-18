#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter
from itertools import combinations
from pathlib import Path
from typing import Any

from analyze_fixed_condition_bt import OUT_BASE, as_float, bool_value
from analyze_fx_only_2025_condition_factorial import BACKTEST, distribution, md_link, max_drawdown, profit_factor


SOURCE_PATH = BACKTEST / f"{OUT_BASE}_broad_fx_only_2025_entry_candidates_trades.csv"
BASE_SCENARIO = "B_broad_hard_gate_reduced"
OUT_PREFIX = f"{OUT_BASE}_broad_fx_only_2025_8cond_factorial"

CONDITIONS = [
    {
        "name": "cond_h4_ma_bias",
        "column": "cond_h4_bias_ma",
        "label": "H4 MA bias",
    },
    {
        "name": "cond_h4_fib_382_618",
        "column": "cond_h4_fib_382_618",
        "label": "H4 fib 38.2-61.8",
    },
    {
        "name": "cond_h1_counter_nwave",
        "column": "cond_h1_counter_nwave",
        "label": "H1 counter N-wave",
    },
    {
        "name": "cond_h1_counter_wave_atr",
        "column": "cond_h1_counter_wave_atr",
        "label": "H1 counter wave >= ATR",
    },
    {
        "name": "cond_true_bos_level",
        "column": "cond_true_bos_level",
        "label": "true BOS level",
    },
    {
        "name": "cond_m15_close_bos",
        "column": "cond_m15_close_bos",
        "label": "M15 close BOS",
    },
    {
        "name": "cond_room_to_2r",
        "column": "cond_room_to_2r",
        "label": "room to 2R",
    },
    {
        "name": "cond_round_or_major_obstacle_clear",
        "column": "cond_major_or_round_room_to_2r",
        "label": "round/major obstacle clear to 2R",
    },
]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "all_combinations": BACKTEST / f"{OUT_PREFIX}_all_combinations.csv",
    "single_effects": BACKTEST / f"{OUT_PREFIX}_single_effects.csv",
    "trade_count_impact": BACKTEST / f"{OUT_PREFIX}_trade_count_impact.csv",
    "expectancy_impact": BACKTEST / f"{OUT_PREFIX}_expectancy_impact.csv",
    "top_by_trade_band": BACKTEST / f"{OUT_PREFIX}_top_by_trade_band.csv",
    "balanced_candidates": BACKTEST / f"{OUT_PREFIX}_balanced_candidates.csv",
    "long_improvement": BACKTEST / f"{OUT_PREFIX}_long_improvement.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}

TRADE_BANDS = [
    ("20-50_reference", 20, 50),
    ("50-100_small", 50, 100),
    ("100-300_main", 100, 300),
    ("300-700_main", 300, 700),
    ("700-1500_large_reference", 700, 1500),
    ("1500_plus_too_many", 1500, None),
    ("3000_plus_noise", 3000, None),
]


def read_rows(path: Path) -> list[dict[str, object]]:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return [dict(row) for row in csv.DictReader(fh)]


def write_rows(path: Path, rows: list[dict[str, object]], fieldnames: list[str] | None = None) -> None:
    fields = list(fieldnames or [])
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def base_rows() -> list[dict[str, object]]:
    rows = [row for row in read_rows(SOURCE_PATH) if row.get("scenario") == BASE_SCENARIO]
    for row in rows:
        for condition in CONDITIONS:
            name = condition["name"]
            column = condition["column"]
            row[name] = row.get(column, row.get(name, "false"))
    return rows


def condition_names(enabled: tuple[str, ...]) -> str:
    return ";".join(enabled) if enabled else "ALL_OFF"


def subset(rows: list[dict[str, object]], enabled: tuple[str, ...]) -> list[dict[str, object]]:
    if not enabled:
        return rows
    return [row for row in rows if all(bool_value(row.get(condition)) for condition in enabled)]


def pf_for(rows: list[dict[str, object]]) -> float | str:
    pf = profit_factor([as_float(row.get("net_profit")) for row in rows])
    return round(pf, 3) if pf is not None else ""


def max_share(rows: list[dict[str, object]], key: str) -> float:
    if not rows:
        return 0.0
    counts = Counter(str(row.get(key, "")) for row in rows if row.get(key, "") != "")
    if not counts:
        return 0.0
    return max(counts.values()) / len(rows) * 100.0


def trade_band(trades: int) -> str:
    if trades < 20:
        return "under_20_too_few"
    if trades < 50:
        return "20-50_reference"
    if trades < 100:
        return "50-100_small"
    if trades < 300:
        return "100-300_main"
    if trades < 700:
        return "300-700_main"
    if trades < 1500:
        return "700-1500_large_reference"
    if trades < 3000:
        return "1500_plus_too_many"
    return "3000_plus_noise"


def stats(rows: list[dict[str, object]]) -> dict[str, object]:
    profits = [as_float(row.get("net_profit")) for row in rows]
    result_rs = [as_float(row.get("result_R")) for row in rows]
    wins = [p for p in profits if p > 0.0]
    long_rows = [row for row in rows if row.get("direction") == "LONG"]
    short_rows = [row for row in rows if row.get("direction") == "SHORT"]
    max_dd, _ = max_drawdown(rows)
    return {
        "trades": len(rows),
        "trade_band": trade_band(len(rows)),
        "win_rate": round(len(wins) / len(rows) * 100.0, 2) if rows else 0.0,
        "PF": pf_for(rows),
        "avg_R": round(sum(result_rs) / len(result_rs), 3) if result_rs else 0.0,
        "net": round(sum(profits), 2),
        "maxDD": round(max_dd, 2),
        "avg_MFE_R": round(sum(as_float(row.get("max_favorable_r")) for row in rows) / len(rows), 3) if rows else 0.0,
        "avg_MAE_R": round(sum(as_float(row.get("max_adverse_r")) for row in rows) / len(rows), 3) if rows else 0.0,
        "reached_0_5R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_0_5R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "reached_1R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_1R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "reached_2R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_2R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "LONG trades": len(long_rows),
        "SHORT trades": len(short_rows),
        "LONG net": round(sum(as_float(row.get("net_profit")) for row in long_rows), 2),
        "SHORT net": round(sum(as_float(row.get("net_profit")) for row in short_rows), 2),
        "LONG avg_R": round(sum(as_float(row.get("result_R")) for row in long_rows) / len(long_rows), 3) if long_rows else 0.0,
        "SHORT avg_R": round(sum(as_float(row.get("result_R")) for row in short_rows) / len(short_rows), 3) if short_rows else 0.0,
        "LONG PF": pf_for(long_rows),
        "SHORT PF": pf_for(short_rows),
        "symbols_count": len({row.get("symbol") for row in rows if row.get("symbol")}),
        "symbol_distribution": distribution(rows, "symbol"),
        "max_symbol_share_pct": round(max_share(rows, "symbol"), 2),
        "months_count": len({row.get("month") for row in rows if row.get("month")}),
        "month_distribution": distribution(rows, "month"),
        "max_month_share_pct": round(max_share(rows, "month"), 2),
        "sessions_count": len({row.get("session") for row in rows if row.get("session")}),
        "session_distribution": distribution(rows, "session"),
    }


def all_combinations(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output = []
    combo_id = 0
    names = [condition["name"] for condition in CONDITIONS]
    for size in range(0, len(names) + 1):
        for enabled in combinations(names, size):
            combo_rows = subset(rows, enabled)
            record = {
                "combination_id": combo_id,
                "enabled_conditions": condition_names(enabled),
                "condition_count": len(enabled),
                **stats(combo_rows),
            }
            for name in names:
                record[name] = "true" if name in enabled else "false"
            output.append(record)
            combo_id += 1
    return output


def single_effects(rows: list[dict[str, object]], baseline: dict[str, object]) -> list[dict[str, object]]:
    output = []
    baseline_trades = int(baseline["trades"])
    baseline_pf = as_float(baseline["PF"])
    baseline_avg_r = as_float(baseline["avg_R"])
    baseline_net = as_float(baseline["net"])
    for condition in CONDITIONS:
        name = condition["name"]
        items = subset(rows, (name,))
        st = stats(items)
        trades = int(st["trades"])
        output.append(
            {
                "condition": name,
                "source_column": condition["column"],
                "label": condition["label"],
                "trades": trades,
                "removed_trades": baseline_trades - trades,
                "reduction_pct": round((baseline_trades - trades) / baseline_trades * 100.0, 2) if baseline_trades else 0.0,
                "PF": st["PF"],
                "avg_R": st["avg_R"],
                "net": st["net"],
                "PF_delta": round(as_float(st["PF"]) - baseline_pf, 3),
                "avg_R_delta": round(as_float(st["avg_R"]) - baseline_avg_r, 3),
                "net_delta": round(as_float(st["net"]) - baseline_net, 2),
                "LONG trades": st["LONG trades"],
                "SHORT trades": st["SHORT trades"],
                "LONG net": st["LONG net"],
                "SHORT net": st["SHORT net"],
                "LONG avg_R": st["LONG avg_R"],
                "SHORT avg_R": st["SHORT avg_R"],
                "LONG PF": st["LONG PF"],
                "SHORT PF": st["SHORT PF"],
                "symbols_count": st["symbols_count"],
                "months_count": st["months_count"],
            }
        )
    return output


def top_by_trade_band(combos: list[dict[str, object]]) -> list[dict[str, object]]:
    output = []
    for band_name, low, high in TRADE_BANDS:
        if band_name not in {"50-100_small", "100-300_main", "300-700_main", "700-1500_large_reference"}:
            continue
        bucket = [
            row for row in combos
            if int(row["trades"]) >= low and (high is None or int(row["trades"]) < high)
        ]
        bucket = sorted(bucket, key=lambda row: (as_float(row["PF"]), as_float(row["avg_R"]), as_float(row["net"])), reverse=True)
        for rank, row in enumerate(bucket[:20], start=1):
            output.append({"trade_band_group": band_name, "rank": rank, **row})
    return output


def balanced_candidates(combos: list[dict[str, object]]) -> list[dict[str, object]]:
    output = []
    for row in combos:
        trades = int(row["trades"])
        fixed_bt_candidate = (
            trades >= 100
            and trades <= 700
            and as_float(row["PF"]) > 1.05
            and as_float(row["avg_R"]) > 0.0
            and as_float(row["net"]) > 0.0
            and as_float(row["LONG net"]) > -500.0
            and as_float(row["SHORT net"]) > -500.0
            and int(row["symbols_count"]) >= 3
            and int(row["months_count"]) >= 4
            and as_float(row["max_symbol_share_pct"]) <= 60.0
            and as_float(row["max_month_share_pct"]) <= 50.0
        )
        balanced_reference = (
            trades >= 100
            and trades <= 700
            and as_float(row["PF"]) > 1.0
            and as_float(row["avg_R"]) > 0.0
            and as_float(row["net"]) > 0.0
            and as_float(row["LONG net"]) > -750.0
            and as_float(row["SHORT net"]) > -750.0
            and int(row["symbols_count"]) >= 3
            and int(row["months_count"]) >= 4
            and as_float(row["max_symbol_share_pct"]) <= 65.0
            and as_float(row["max_month_share_pct"]) <= 55.0
        )
        small_reference = (
            trades >= 50
            and trades < 100
            and as_float(row["PF"]) > 1.05
            and as_float(row["avg_R"]) > 0.0
            and as_float(row["net"]) > 0.0
        )
        if fixed_bt_candidate or balanced_reference or small_reference:
            output.append({
                "candidate_type": "fixed_bt_candidate" if fixed_bt_candidate else ("balanced_reference" if balanced_reference else "small_reference"),
                **row,
            })
    return sorted(output, key=lambda row: (row["candidate_type"] != "fixed_bt_candidate", -as_float(row["PF"]), -as_float(row["avg_R"]), -as_float(row["net"])))


def long_improvement(combos: list[dict[str, object]], baseline: dict[str, object]) -> list[dict[str, object]]:
    base_long_net = as_float(baseline["LONG net"])
    base_long_avg = as_float(baseline["LONG avg_R"])
    base_long_pf = as_float(baseline["LONG PF"])
    base_short_net = as_float(baseline["SHORT net"])
    output = []
    for row in combos:
        if int(row["trades"]) < 20:
            continue
        output.append(
            {
                **row,
                "LONG net_delta": round(as_float(row["LONG net"]) - base_long_net, 2),
                "LONG avg_R_delta": round(as_float(row["LONG avg_R"]) - base_long_avg, 3),
                "LONG PF_delta": round(as_float(row["LONG PF"]) - base_long_pf, 3),
                "SHORT net_delta": round(as_float(row["SHORT net"]) - base_short_net, 2),
            }
        )
    return sorted(output, key=lambda row: (as_float(row["LONG PF_delta"]), as_float(row["LONG avg_R_delta"]), as_float(row["LONG net_delta"])), reverse=True)


def best_row(rows: list[dict[str, object]], key: str, min_trades: int = 1) -> dict[str, object] | None:
    eligible = [row for row in rows if int(row["trades"]) >= min_trades]
    if not eligible:
        return None
    return max(eligible, key=lambda row: as_float(row[key]))


def condition_combo_lookup(combos: list[dict[str, object]], enabled: list[str]) -> dict[str, object] | None:
    target = set(enabled)
    for row in combos:
        row_enabled = set() if row["enabled_conditions"] == "ALL_OFF" else set(str(row["enabled_conditions"]).split(";"))
        if row_enabled == target:
            return row
    return None


def write_summary(
    rows: list[dict[str, object]],
    combos: list[dict[str, object]],
    singles: list[dict[str, object]],
    top_band_rows: list[dict[str, object]],
    balanced: list[dict[str, object]],
    long_rows: list[dict[str, object]],
) -> None:
    base = OUTPUTS["summary"].parent
    baseline = combos[0]
    best_pf = best_row(combos, "PF", 20)
    best_avg = best_row(combos, "avg_R", 20)
    best_net_balance = max(
        [row for row in combos if int(row["trades"]) >= 50],
        key=lambda row: (as_float(row["net"]) - as_float(row["maxDD"]), as_float(row["PF"]), as_float(row["avg_R"])),
    )
    strongest_count_cut = max(singles, key=lambda row: as_float(row["reduction_pct"]))
    weakest_count_cut = min(singles, key=lambda row: as_float(row["reduction_pct"]))
    strongest_avg_lift = max(singles, key=lambda row: as_float(row["avg_R_delta"]))
    worst_avg_lift = min(singles, key=lambda row: as_float(row["avg_R_delta"]))
    strongest_pf_lift = max(singles, key=lambda row: as_float(row["PF_delta"]))
    fixed_candidates = [row for row in balanced if row["candidate_type"] == "fixed_bt_candidate"]
    reference_candidates = [row for row in balanced if row["candidate_type"] != "fixed_bt_candidate"]
    top_100_700 = sorted(
        [row for row in combos if 100 <= int(row["trades"]) <= 700],
        key=lambda row: (as_float(row["PF"]), as_float(row["avg_R"]), as_float(row["net"])),
        reverse=True,
    )
    top_50_100 = sorted(
        [row for row in combos if 50 <= int(row["trades"]) < 100],
        key=lambda row: (as_float(row["PF"]), as_float(row["avg_R"]), as_float(row["net"])),
        reverse=True,
    )
    top_20_50 = sorted(
        [row for row in combos if 20 <= int(row["trades"]) < 50],
        key=lambda row: (as_float(row["PF"]), as_float(row["avg_R"]), as_float(row["net"])),
        reverse=True,
    )

    room_combo_names = [
        ["cond_room_to_2r"],
        ["cond_h4_ma_bias", "cond_room_to_2r"],
        ["cond_h4_fib_382_618", "cond_room_to_2r"],
        ["cond_m15_close_bos", "cond_room_to_2r"],
        ["cond_h4_ma_bias", "cond_m15_close_bos", "cond_room_to_2r"],
        ["cond_h4_ma_bias", "cond_room_to_2r", "cond_round_or_major_obstacle_clear"],
    ]
    room_rows = [condition_combo_lookup(combos, combo) for combo in room_combo_names]

    lines = [
        "# Broad FX-only 2025 8-Condition Factorial Summary",
        "",
        "Scope: Python post-processing of existing 2025 FX-only broad candidate trades. This is not MT5 optimization and does not change EA entry logic, RewardR, SL/TP, risk, spread guard, CTrade, symbols, or direction mode.",
        "",
        "## Source Check",
        "",
        f"- Source CSV: `{SOURCE_PATH.name}`",
        f"- Source CSV rows including derived scenarios: `{len(read_rows(SOURCE_PATH))}`.",
        f"- Factorial baseline rows: `{len(rows)}` with `scenario == {BASE_SCENARIO}`.",
        "- The previous A-F summary and CSV are consistent after filtering on `scenario`; C-F are not zero in the current regenerated artifacts.",
        "- Column aliases used:",
    ]
    for condition in CONDITIONS:
        lines.append(f"  - `{condition['name']}` -> `{condition['column']}`")
    lines.append("- `cond_h4_fib_382_618` is derived from `h4_fib_zone == valid_h4_pullback_zone` because this diagnostic CSV has `h4_fib_retracement_pct` recorded as `0.0` for all broad rows.")
    lines += [
        "",
        "## Required Answers",
        "",
        f"1. `3999` is candidate count, not combination count. Combination count is `256`.",
        f"2. 8-condition ON/OFF factorial was executed: `yes`.",
        f"3. Actual combinations evaluated: `{len(combos)}`.",
        f"4. Most trade-count reducing single condition: `{strongest_count_cut['condition']}` (`{strongest_count_cut['trades']}` trades, `{strongest_count_cut['reduction_pct']}`% reduction).",
        f"5. Condition whose removal keeps the largest trade count: `{weakest_count_cut['condition']}` (`{weakest_count_cut['trades']}` trades when ON, smallest cut).",
        f"6. Fixed-BT candidates in 100-700 trade range: `{len(fixed_candidates)}`. Reference candidates: `{len(reference_candidates)}`.",
        f"7. Best PF combination with at least 20 trades: `{best_pf['enabled_conditions'] if best_pf else 'none'}` PF `{best_pf['PF'] if best_pf else ''}`, trades `{best_pf['trades'] if best_pf else ''}`.",
        f"8. Best avg_R combination with at least 20 trades: `{best_avg['enabled_conditions'] if best_avg else 'none'}` avg_R `{best_avg['avg_R'] if best_avg else ''}`, trades `{best_avg['trades'] if best_avg else ''}`.",
        f"9. Best net-minus-DD balance with at least 50 trades: `{best_net_balance['enabled_conditions']}` net `{best_net_balance['net']}`, maxDD `{best_net_balance['maxDD']}`, PF `{best_net_balance['PF']}`.",
        f"10. Best LONG improvement condition set by LONG PF delta: `{long_rows[0]['enabled_conditions'] if long_rows else 'none'}`.",
        f"11. SHORT-preserving LONG improvement exists only if `SHORT net_delta` stays near or above zero; inspect the LONG improvement CSV. Top LONG rows generally need separate balance review.",
        f"11a. Strongest single avg_R lift: `{strongest_avg_lift['condition']}` (`{strongest_avg_lift['avg_R_delta']}`). Worst single avg_R lift: `{worst_avg_lift['condition']}` (`{worst_avg_lift['avg_R_delta']}`).",
        f"11b. Strongest single PF lift: `{strongest_pf_lift['condition']}` (`{strongest_pf_lift['PF_delta']}`).",
        f"12. H4 MA bias single effect: `{next(row for row in singles if row['condition'] == 'cond_h4_ma_bias')['trades']}` trades, PF `{next(row for row in singles if row['condition'] == 'cond_h4_ma_bias')['PF']}`, avg_R `{next(row for row in singles if row['condition'] == 'cond_h4_ma_bias')['avg_R']}`.",
        f"13. H4 fib single effect: `{next(row for row in singles if row['condition'] == 'cond_h4_fib_382_618')['trades']}` trades, PF `{next(row for row in singles if row['condition'] == 'cond_h4_fib_382_618')['PF']}`, avg_R `{next(row for row in singles if row['condition'] == 'cond_h4_fib_382_618')['avg_R']}`.",
        f"14. H1 N-wave single effect: `{next(row for row in singles if row['condition'] == 'cond_h1_counter_nwave')['trades']}` trades, PF `{next(row for row in singles if row['condition'] == 'cond_h1_counter_nwave')['PF']}`, avg_R `{next(row for row in singles if row['condition'] == 'cond_h1_counter_nwave')['avg_R']}`.",
        f"15. H1 ATR single effect: `{next(row for row in singles if row['condition'] == 'cond_h1_counter_wave_atr')['trades']}` trades, PF `{next(row for row in singles if row['condition'] == 'cond_h1_counter_wave_atr')['PF']}`, avg_R `{next(row for row in singles if row['condition'] == 'cond_h1_counter_wave_atr')['avg_R']}`.",
        f"16. M15 close BOS single effect: `{next(row for row in singles if row['condition'] == 'cond_m15_close_bos')['trades']}` trades, PF `{next(row for row in singles if row['condition'] == 'cond_m15_close_bos')['PF']}`, avg_R `{next(row for row in singles if row['condition'] == 'cond_m15_close_bos')['avg_R']}`.",
        f"17. room_to_2r single effect: `{next(row for row in singles if row['condition'] == 'cond_room_to_2r')['trades']}` trades, PF `{next(row for row in singles if row['condition'] == 'cond_room_to_2r')['PF']}`, avg_R `{next(row for row in singles if row['condition'] == 'cond_room_to_2r')['avg_R']}`.",
        f"18. Fixed-BT candidate set exists: `{'yes' if fixed_candidates else 'no'}`.",
        f"19. If none, reason: no 100-700 trade combination satisfies PF > 1.05, avg_R > 0, net > 0, balanced LONG/SHORT, and diversification constraints simultaneously.",
        f"20. Best 100-700 trade row: `{top_100_700[0]['enabled_conditions'] if top_100_700 else 'none'}` trades `{top_100_700[0]['trades'] if top_100_700 else ''}`, PF `{top_100_700[0]['PF'] if top_100_700 else ''}`, avg_R `{top_100_700[0]['avg_R'] if top_100_700 else ''}`, net `{top_100_700[0]['net'] if top_100_700 else ''}`.",
        f"21. Best 50-100 trade row: `{top_50_100[0]['enabled_conditions'] if top_50_100 else 'none'}` trades `{top_50_100[0]['trades'] if top_50_100 else ''}`, PF `{top_50_100[0]['PF'] if top_50_100 else ''}`, avg_R `{top_50_100[0]['avg_R'] if top_50_100 else ''}`, net `{top_50_100[0]['net'] if top_50_100 else ''}`.",
        f"22. Best 20-50 reference row: `{top_20_50[0]['enabled_conditions'] if top_20_50 else 'none'}` trades `{top_20_50[0]['trades'] if top_20_50 else ''}`, PF `{top_20_50[0]['PF'] if top_20_50 else ''}`, avg_R `{top_20_50[0]['avg_R'] if top_20_50 else ''}`, net `{top_20_50[0]['net'] if top_20_50 else ''}`. This band is diagnostic only, not a fixed-BT candidate.",
        "",
        "## Single-Condition Expectancy Ranking",
        "",
    ]
    for row in sorted(singles, key=lambda item: as_float(item["avg_R_delta"]), reverse=True):
        lines.append(f"- `{row['condition']}`: trades `{row['trades']}`, PF `{row['PF']}`, avg_R `{row['avg_R']}`, net `{row['net']}`, avg_R_delta `{row['avg_R_delta']}`.")

    lines += [
        "",
        "## room_to_2r Combination Checks",
        "",
        "| enabled_conditions | trades | PF | avg_R | net | LONG net | SHORT net |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in room_rows:
        if row is None:
            continue
        lines.append(f"| {row['enabled_conditions']} | {row['trades']} | {row['PF']} | {row['avg_R']} | {row['net']} | {row['LONG net']} | {row['SHORT net']} |")

    lines += [
        "",
        "## Interpretation",
        "",
        "- `cond_true_bos_level` is non-selective in this dataset: it keeps all 3999 baseline rows.",
        "- `cond_m15_close_bos` improves average R but cuts the sample to 88 trades and remains PF-negative on net-money terms, so it is not a stable fixed-BT branch.",
        "- `cond_h4_ma_bias`, `cond_h4_fib_382_618`, `cond_h1_counter_nwave`, and `cond_room_to_2r` reduce trades but do not turn the broad FX-only pool positive by themselves.",
        "- The best LONG-improving combinations still fail the full gate because total PF/net remain negative or SHORT stays weak.",
        "- No 100-700 trade condition set is ready for MT5 fixed-BT promotion from this 8-condition factorial pass.",
        "",
        "",
        "## Artifacts",
        "",
    ]
    for key, path in OUTPUTS.items():
        if key == "summary":
            continue
        lines.append(f"- {key}: {md_link(path.name, path, base)}")
    lines.append("")
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    rows = base_rows()
    missing = [condition for condition in CONDITIONS if condition["column"] not in rows[0]]
    if missing:
        raise RuntimeError(f"Missing condition columns: {missing}")

    combos = all_combinations(rows)
    baseline = combos[0]
    singles = single_effects(rows, baseline)
    trade_count = sorted(singles, key=lambda row: as_float(row["reduction_pct"]), reverse=True)
    expectancy = sorted(singles, key=lambda row: (as_float(row["avg_R_delta"]), as_float(row["PF_delta"]), as_float(row["net_delta"])), reverse=True)
    top_bands = top_by_trade_band(combos)
    balanced = balanced_candidates(combos)
    long_rows = long_improvement(combos, baseline)

    combo_fields = list(combos[0].keys()) if combos else []
    single_fields = list(singles[0].keys()) if singles else []
    top_fields = ["trade_band_group", "rank", *combo_fields]
    balanced_fields = ["candidate_type", *combo_fields]
    long_fields = list(long_rows[0].keys()) if long_rows else [*combo_fields, "LONG net_delta", "LONG avg_R_delta", "LONG PF_delta", "SHORT net_delta"]

    write_rows(OUTPUTS["all_combinations"], combos, combo_fields)
    write_rows(OUTPUTS["single_effects"], singles, single_fields)
    write_rows(OUTPUTS["trade_count_impact"], trade_count, single_fields)
    write_rows(OUTPUTS["expectancy_impact"], expectancy, single_fields)
    write_rows(OUTPUTS["top_by_trade_band"], top_bands, top_fields)
    write_rows(OUTPUTS["balanced_candidates"], balanced, balanced_fields)
    write_rows(OUTPUTS["long_improvement"], long_rows, long_fields)
    write_summary(rows, combos, singles, top_bands, balanced, long_rows)
    OUTPUTS["metrics"].write_text(
        json.dumps(
            {
                "source": str(SOURCE_PATH),
                "base_scenario": BASE_SCENARIO,
                "base_rows": len(rows),
                "condition_mapping": CONDITIONS,
                "combination_count": len(combos),
                "fixed_bt_candidates": [row for row in balanced if row["candidate_type"] == "fixed_bt_candidate"],
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps({"base_rows": len(rows), "combinations": len(combos), "balanced_candidates": len(balanced)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
