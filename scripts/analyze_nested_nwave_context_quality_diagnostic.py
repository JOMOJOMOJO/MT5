#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from analyze_multicurrency_score_scanner_2025 import BACKTEST, calc_stats
from analyze_nested_nwave_failure_decomposition import as_float, as_int, pf_value


ROOT = Path(__file__).resolve().parents[1]
OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
IN_PATH = BACKTEST / f"{OUT_BASE}_nested_nwave_router_decision_audit.csv"
OUT_PREFIX = f"{OUT_BASE}_nested_nwave_context_quality_diagnostic"
DEVLOG = ROOT / "docs" / "devlog" / "2026-06-15-nested-nwave-context-quality-diagnostic.md"

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "bucket_matrix": BACKTEST / f"{OUT_PREFIX}_bucket_matrix.csv",
    "cohort_diff": BACKTEST / f"{OUT_PREFIX}_cohort_diff.csv",
    "candidate_rows": BACKTEST / f"{OUT_PREFIX}_candidate_rows.csv",
    "next_router_notes": BACKTEST / f"{OUT_PREFIX}_next_router_notes.md",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def bucket_h4_fib(value: float) -> str:
    if value <= 0:
        return "unknown"
    if value < 42:
        return "38-42_shallow_edge"
    if value < 50:
        return "42-50_mid"
    if value < 58:
        return "50-58_mid"
    return "58-62_deep_edge"


def bucket_sl_atr(value: float) -> str:
    if value <= 0:
        return "unknown"
    if value < 1.0:
        return "<1.0_tight"
    if value < 1.5:
        return "1.0-1.5"
    if value < 2.0:
        return "1.5-2.0"
    return "2.0+_wide"


def bucket_touch(value: int) -> str:
    if value <= 0:
        return "unknown"
    if value <= 4:
        return "1-4_fresh"
    if value <= 8:
        return "5-8_moderate"
    if value <= 12:
        return "9-12_tested"
    return "13+_stale"


def bucket_close_strength(value: float) -> str:
    if value < 0.35:
        return "<0.35_weak_close"
    if value < 0.60:
        return "0.35-0.60_mixed_close"
    return "0.60+_strong_close"


def bucket_close_distance(value: float) -> str:
    if value < 0.20:
        return "<0.20_shallow_break"
    if value < 0.40:
        return "0.20-0.40_normal"
    if value < 0.80:
        return "0.40-0.80_extended"
    return "0.80+_far"


def bucket_body_atr(value: float) -> str:
    if value < 0.25:
        return "<0.25_small_body"
    if value < 0.60:
        return "0.25-0.60_normal"
    if value < 1.00:
        return "0.60-1.00_large"
    return "1.00+_overextended"


def bucket_body_ratio(value: float) -> str:
    if value < 0.30:
        return "<0.30_wicky"
    if value < 0.60:
        return "0.30-0.60_mixed"
    return "0.60+_body"


def bucket_wick(value: float) -> str:
    if value < 0.20:
        return "<0.20_clean_wick"
    if value < 0.45:
        return "0.20-0.45_mixed_wick"
    return "0.45+_large_wick"


def bucket_mfe(value: float) -> str:
    if value < 0.5:
        return "<0.5R"
    if value < 1.0:
        return "0.5-1R"
    if value < 1.5:
        return "1-1.5R"
    if value < 2.0:
        return "1.5-2R"
    return "2R+"


def cohort_name(row: dict[str, object]) -> str:
    period = row["period"]
    result_r = as_float(row.get("hypothetical_result_R"))
    if period == "2025-10" and result_r > 0:
        return "2025_10_removed_winner_dirty_weak"
    if period == "2025-10" and result_r < 0:
        return "2025_10_removed_loser_dirty_weak"
    if period == "2026-Q1" and result_r < 0:
        return "2026_q1_avoided_loser_dirty_weak"
    if period == "2026-Q1" and result_r > 0:
        return "2026_q1_removed_winner_dirty_weak"
    return f"{period}_other_dirty_weak"


def context_quality_v0(row: dict[str, object]) -> tuple[str, str, int]:
    score = 0
    penalties = 0
    reasons: list[str] = []

    h4_bucket = str(row["h4_fib_bucket"])
    if h4_bucket in {"42-50_mid", "50-58_mid"}:
        score += 1
        reasons.append("h4_mid_pullback")
    else:
        penalties += 1
        reasons.append("h4_edge_pullback")

    touch = as_int(row.get("neckline_touch_count"))
    if touch <= 8:
        score += 1
        reasons.append("neckline_not_stale")
    else:
        penalties += 1
        reasons.append("neckline_over_tested")

    sl_atr = as_float(row.get("sl_atr"))
    if 0 < sl_atr < 2.0:
        score += 1
        reasons.append("sl_atr_ok")
    else:
        penalties += 1
        reasons.append("sl_atr_wide_or_unknown")

    close_distance = as_float(row.get("breakout_close_distance_from_neckline_atr"))
    if 0.20 <= close_distance <= 0.80:
        score += 1
        reasons.append("break_distance_usable")
    elif close_distance < 0.20:
        penalties += 1
        reasons.append("break_too_shallow")
    else:
        penalties += 1
        reasons.append("break_too_far")

    close_strength = as_float(row.get("breakout_close_position_directional"))
    if close_strength >= 0.60:
        score += 1
        reasons.append("directional_close_strong")
    elif close_strength < 0.35:
        penalties += 1
        reasons.append("directional_close_weak")
    else:
        reasons.append("directional_close_mixed")

    body_atr = as_float(row.get("breakout_body_atr"))
    if 0.25 <= body_atr <= 1.00:
        score += 1
        reasons.append("body_atr_usable")
    elif body_atr < 0.25:
        penalties += 1
        reasons.append("body_too_small")
    else:
        penalties += 1
        reasons.append("body_overextended")

    wick = as_float(row.get("breakout_directional_wick_ratio"))
    if wick < 0.45:
        score += 1
        reasons.append("wick_ok")
    else:
        penalties += 1
        reasons.append("large_directional_wick")

    if score >= 5 and penalties <= 1:
        label = "clean_context_v0"
    elif score <= 3 or penalties >= 3:
        label = "poor_context_v0"
    else:
        label = "mixed_context_v0"
    return label, "|".join(reasons), score


def enrich(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    for row in rows:
        if row.get("entry_selection_mode") != "ALL_SCORE_PASSING":
            continue
        if row.get("router_decision") not in {"dirty_skipped", "weak_routed_to_retest"}:
            continue
        parsed: dict[str, object] = dict(row)
        numeric_fields = [
            "h4_fib_retracement_pct",
            "entry_price",
            "sl",
            "tp",
            "volume",
            "risk_r",
            "rr",
            "sl_atr",
            "tp_atr",
            "distance_neckline_to_entry_atr",
            "breakout_close_distance_from_neckline_atr",
            "breakout_body_ratio",
            "breakout_body_atr",
            "breakout_range_atr",
            "breakout_directional_wick_ratio",
            "breakout_close_position_directional",
            "hypothetical_result_R",
            "hypothetical_net_profit",
            "max_favorable_r",
            "max_adverse_r",
        ]
        for field in numeric_fields:
            parsed[field] = as_float(parsed.get(field))
        for field in [
            "neckline_touch_count",
            "same_bar_ambiguous",
            "bars_to_exit",
            "reached_0_5R",
            "reached_1R",
            "reached_1_5R",
            "reached_2R",
            "reached_3R",
            "false_break_return_inside_neckline",
        ]:
            parsed[field] = as_int(parsed.get(field))

        parsed["cohort"] = cohort_name(parsed)
        parsed["h4_fib_bucket"] = bucket_h4_fib(as_float(parsed["h4_fib_retracement_pct"]))
        parsed["sl_atr_bucket"] = bucket_sl_atr(as_float(parsed["sl_atr"]))
        parsed["neckline_touch_bucket"] = bucket_touch(as_int(parsed["neckline_touch_count"]))
        parsed["close_strength_bucket"] = bucket_close_strength(as_float(parsed["breakout_close_position_directional"]))
        parsed["close_distance_bucket"] = bucket_close_distance(as_float(parsed["breakout_close_distance_from_neckline_atr"]))
        parsed["body_atr_bucket"] = bucket_body_atr(as_float(parsed["breakout_body_atr"]))
        parsed["body_ratio_bucket"] = bucket_body_ratio(as_float(parsed["breakout_body_ratio"]))
        parsed["directional_wick_bucket"] = bucket_wick(as_float(parsed["breakout_directional_wick_ratio"]))
        parsed["mfe_bucket"] = bucket_mfe(as_float(parsed["max_favorable_r"]))
        parsed["mae_bucket"] = bucket_mfe(as_float(parsed["max_adverse_r"]))
        quality, reasons, score = context_quality_v0(parsed)
        parsed["context_quality_v0"] = quality
        parsed["context_quality_reasons_v0"] = reasons
        parsed["context_quality_score_v0"] = score
        output.append(parsed)
    return output


def stats_for_rows(rows: list[dict[str, object]]) -> dict[str, object]:
    synthetic = []
    base = datetime(2000, 1, 1)
    for idx, row in enumerate(rows):
        synthetic.append(
            {
                "net_profit": as_float(row.get("hypothetical_net_profit")),
                "open_time": base + timedelta(minutes=idx),
                "close_time": base + timedelta(minutes=idx + 1),
            }
        )
    return calc_stats(synthetic)


def aggregate(rows: list[dict[str, object]], group_fields: list[str]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(field, "")) for field in group_fields)].append(row)
    result: list[dict[str, object]] = []
    for key, bucket in sorted(buckets.items()):
        stats = stats_for_rows(bucket)
        row = {field: value for field, value in zip(group_fields, key)}
        row.update(
            {
                "candidates": len(bucket),
                "wins": sum(1 for item in bucket if as_float(item.get("hypothetical_result_R")) > 0),
                "losses": sum(1 for item in bucket if as_float(item.get("hypothetical_result_R")) < 0),
                "win_rate": round(sum(1 for item in bucket if as_float(item.get("hypothetical_result_R")) > 0) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "net": round(sum(as_float(item.get("hypothetical_net_profit")) for item in bucket), 2),
                "PF": pf_value(stats),
                "avg_R": round(sum(as_float(item.get("hypothetical_result_R")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_MFE_R": round(sum(as_float(item.get("max_favorable_r")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_MAE_R": round(sum(as_float(item.get("max_adverse_r")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
                "reached_1R_pct": round(sum(as_int(item.get("reached_1R")) for item in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "reached_2R_pct": round(sum(as_int(item.get("reached_2R")) for item in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "false_return_pct": round(sum(as_int(item.get("false_break_return_inside_neckline")) for item in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "avg_h4_fib": round(sum(as_float(item.get("h4_fib_retracement_pct")) for item in bucket) / len(bucket), 2) if bucket else 0.0,
                "avg_sl_atr": round(sum(as_float(item.get("sl_atr")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_touch_count": round(sum(as_int(item.get("neckline_touch_count")) for item in bucket) / len(bucket), 2) if bucket else 0.0,
                "avg_close_strength": round(sum(as_float(item.get("breakout_close_position_directional")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_close_distance_atr": round(sum(as_float(item.get("breakout_close_distance_from_neckline_atr")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_context_score_v0": round(sum(as_int(item.get("context_quality_score_v0")) for item in bucket) / len(bucket), 2) if bucket else 0.0,
            }
        )
        result.append(row)
    return result


BUCKET_FIELDS = [
    "context_quality_v0",
    "h4_fib_bucket",
    "sl_atr_bucket",
    "neckline_touch_bucket",
    "close_strength_bucket",
    "close_distance_bucket",
    "body_atr_bucket",
    "body_ratio_bucket",
    "directional_wick_bucket",
    "mfe_bucket",
    "mae_bucket",
    "symbol",
    "direction",
    "fx_bucket",
    "session",
    "breakout_quality_reason",
]


def bucket_matrix(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    for field in BUCKET_FIELDS:
        for row in aggregate(rows, ["cohort", "router_decision", field]):
            row["feature"] = field
            row["bucket"] = row.pop(field)
            output.append(row)
    return output


def cohort_diff(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    target_cohorts = [
        "2025_10_removed_winner_dirty_weak",
        "2026_q1_avoided_loser_dirty_weak",
    ]
    output: list[dict[str, object]] = []
    for field in BUCKET_FIELDS:
        counts: dict[str, Counter[str]] = {cohort: Counter() for cohort in target_cohorts}
        totals = {cohort: 0 for cohort in target_cohorts}
        for row in rows:
            cohort = str(row["cohort"])
            if cohort not in counts:
                continue
            counts[cohort][str(row.get(field, ""))] += 1
            totals[cohort] += 1
        buckets = sorted(set().union(*(counter.keys() for counter in counts.values())))
        for bucket in buckets:
            left = counts[target_cohorts[0]][bucket]
            right = counts[target_cohorts[1]][bucket]
            output.append(
                {
                    "feature": field,
                    "bucket": bucket,
                    "2025_10_removed_winners_count": left,
                    "2025_10_removed_winners_share_pct": round(left / totals[target_cohorts[0]] * 100.0, 2) if totals[target_cohorts[0]] else 0.0,
                    "2026_q1_avoided_losers_count": right,
                    "2026_q1_avoided_losers_share_pct": round(right / totals[target_cohorts[1]] * 100.0, 2) if totals[target_cohorts[1]] else 0.0,
                    "share_delta_winners_minus_losers": round(
                        (left / totals[target_cohorts[0]] * 100.0 if totals[target_cohorts[0]] else 0.0)
                        - (right / totals[target_cohorts[1]] * 100.0 if totals[target_cohorts[1]] else 0.0),
                        2,
                    ),
                }
            )
    return output


def top_buckets(diff_rows: list[dict[str, object]], feature: str, positive: bool, limit: int = 5) -> list[dict[str, object]]:
    rows = [row for row in diff_rows if row["feature"] == feature]
    rows.sort(key=lambda row: as_float(row["share_delta_winners_minus_losers"]), reverse=positive)
    return rows[:limit]


def write_summary(rows: list[dict[str, object]], comparison: list[dict[str, object]], diff_rows: list[dict[str, object]]) -> None:
    def find(cohort: str, decision: str = "") -> dict[str, object] | None:
        for row in comparison:
            if row.get("cohort") == cohort and (decision == "" or row.get("router_decision") == decision):
                return row
        return None

    winners = find("2025_10_removed_winner_dirty_weak")
    losers = find("2026_q1_avoided_loser_dirty_weak")
    dirty_winners = find("2025_10_removed_winner_dirty_weak", "dirty_skipped")
    dirty_losers = find("2026_q1_avoided_loser_dirty_weak", "dirty_skipped")
    weak_winners = find("2025_10_removed_winner_dirty_weak", "weak_routed_to_retest")
    weak_losers = find("2026_q1_avoided_loser_dirty_weak", "weak_routed_to_retest")

    lines = [
        "# Nested N-Wave Context Quality Diagnostic",
        "",
        "## Scope",
        "",
        "- This is a diagnostic comparison, not Router v2.",
        "- Existing EA logic, Router labels, order handling, SL/TP, RewardR, timeframe, spread guard, and risk calculation were not changed.",
        "- The comparison focuses on `dirty_breakout` and `weak_breakout` candidates from the prior Router decision audit.",
        "- Main contrast: 2025-10 removed winners versus 2026-Q1 avoided losers.",
        "",
        "## Cohort Summary",
        "",
        "| cohort | candidates | PF | avg_R | net | avg context score | avg H4 fib | avg SL ATR | avg touch count | avg close strength | avg close dist ATR |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in comparison:
        if "router_decision" in row:
            continue
        lines.append(
            f"| {row['cohort']} | {row['candidates']} | {row['PF']} | {row['avg_R']} | {row['net']} | {row['avg_context_score_v0']} | {row['avg_h4_fib']} | {row['avg_sl_atr']} | {row['avg_touch_count']} | {row['avg_close_strength']} | {row['avg_close_distance_atr']} |"
        )

    lines += [
        "",
        "## Dirty / Weak Split",
        "",
        "| cohort | decision | candidates | PF | avg_R | net | false return % | reached 2R % | avg context score |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in comparison:
        if row.get("router_decision", "") == "":
            continue
        if row["cohort"] not in {"2025_10_removed_winner_dirty_weak", "2026_q1_avoided_loser_dirty_weak"}:
            continue
        lines.append(
            f"| {row['cohort']} | {row['router_decision']} | {row['candidates']} | {row['PF']} | {row['avg_R']} | {row['net']} | {row['false_return_pct']} | {row['reached_2R_pct']} | {row['avg_context_score_v0']} |"
        )

    lines += ["", "## Interpretation", ""]
    if winners and losers:
        if as_float(winners["avg_context_score_v0"]) > as_float(losers["avg_context_score_v0"]):
            lines.append(
                f"- The crude `context_quality_v0` score separated the cohorts in the expected direction: 2025-10 removed winners scored `{winners['avg_context_score_v0']}` versus 2026-Q1 avoided losers `{losers['avg_context_score_v0']}`."
            )
        else:
            lines.append(
                f"- The crude `context_quality_v0` score did **not** separate the cohorts: 2025-10 removed winners scored `{winners['avg_context_score_v0']}` while 2026-Q1 avoided losers scored `{losers['avg_context_score_v0']}`. Do not promote this v0 score into a gate."
            )
        lines.append(
            f"- 2025-10 removed winners had lower false-return rate (`{winners['false_return_pct']}%`) than 2026-Q1 avoided losers (`{losers['false_return_pct']}%`)."
        )
        lines.append(
            f"- 2026-Q1 avoided losers had higher average MAE (`{losers['avg_MAE_R']}`R) than the 2025-10 removed winners (`{winners['avg_MAE_R']}`R)."
        )
        lines.append(
            f"- Basic M15 candle strength was not enough: average close strength was `{winners['avg_close_strength']}` for 2025-10 removed winners and `{losers['avg_close_strength']}` for 2026-Q1 avoided losers."
        )
        lines.append(
            "- The strongest observed separators are partly post-entry path metrics (`false_return`, `MAE`, `MFE`). They are useful for diagnosis, but the next implementation needs pre-entry proxies for those paths."
        )
    if dirty_winners and dirty_losers:
        lines.append(
            f"- `dirty` winners in 2025-10 still reached 2R in `{dirty_winners['reached_2R_pct']}%`; `dirty` losers in 2026-Q1 reached 2R in `{dirty_losers['reached_2R_pct']}%`. This supports context-dependent routing rather than a hard dirty skip."
        )
    if weak_winners and weak_losers:
        lines.append(
            f"- `weak` winners in 2025-10 had avg_R `{weak_winners['avg_R']}` versus `weak` losers in 2026-Q1 avg_R `{weak_losers['avg_R']}`. Weak breakout is not intrinsically bad; it needs context classification."
        )

    lines += [
        "",
        "## Buckets More Common In 2025-10 Removed Winners",
        "",
    ]
    for feature in ["context_quality_v0", "sl_atr_bucket", "neckline_touch_bucket", "close_strength_bucket", "close_distance_bucket", "body_atr_bucket", "mfe_bucket"]:
        lines.append(f"- `{feature}`:")
        for row in top_buckets(diff_rows, feature, positive=True, limit=3):
            lines.append(
                f"  - `{row['bucket']}`: winners {row['2025_10_removed_winners_share_pct']}%, Q1 losers {row['2026_q1_avoided_losers_share_pct']}%, delta {row['share_delta_winners_minus_losers']}pt"
            )

    lines += [
        "",
        "## Buckets More Common In 2026-Q1 Avoided Losers",
        "",
    ]
    for feature in ["context_quality_v0", "sl_atr_bucket", "neckline_touch_bucket", "close_strength_bucket", "close_distance_bucket", "body_atr_bucket", "mae_bucket"]:
        lines.append(f"- `{feature}`:")
        for row in top_buckets(diff_rows, feature, positive=False, limit=3):
            lines.append(
                f"  - `{row['bucket']}`: winners {row['2025_10_removed_winners_share_pct']}%, Q1 losers {row['2026_q1_avoided_losers_share_pct']}%, delta {row['share_delta_winners_minus_losers']}pt"
            )

    lines += [
        "",
        "## Next Step",
        "",
        "- Do not implement fixed gates yet.",
        "- Add richer Context Quality diagnostics to the Router branch next. The existing audit columns are not enough: the crude v0 label misclassifies too many 2025-10 winners as poor context.",
        "- Prioritize missing pre-entry context metrics: H4 obstacle room to 2R, H1 counter N-wave break quality, M15 pre-break extension, neckline age, and 1R-to-2R continuation room.",
        "- Keep routing unchanged until those diagnostics prove they preserve 2025-10 winners while continuing to avoid 2026-Q1 false-break losers.",
        "",
        "## Artifacts",
        "",
        f"- Candidate rows: [{OUTPUTS['candidate_rows'].name}]({OUTPUTS['candidate_rows'].name})",
        f"- Comparison CSV: [{OUTPUTS['comparison'].name}]({OUTPUTS['comparison'].name})",
        f"- Bucket matrix: [{OUTPUTS['bucket_matrix'].name}]({OUTPUTS['bucket_matrix'].name})",
        f"- Cohort diff: [{OUTPUTS['cohort_diff'].name}]({OUTPUTS['cohort_diff'].name})",
        f"- Next router notes: [{OUTPUTS['next_router_notes'].name}]({OUTPUTS['next_router_notes'].name})",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_next_router_notes() -> None:
    lines = [
        "# Nested N-Wave Context Quality Notes",
        "",
        "This is a design seed, not implemented routing logic.",
        "",
        "## Desired Classification",
        "",
        "M15 neckline break -> Breakout Candle Quality -> Context Quality -> route.",
        "",
        "| Breakout | Context | Diagnostic route hypothesis |",
        "|---|---|---|",
        "| strong | clean_context | instant entry |",
        "| weak | clean_context | instant entry or shallow retest |",
        "| weak | mixed_context | retest confirmation |",
        "| dirty | clean_context | do not discard; retest/reclaim candidate |",
        "| dirty | poor_context | skip |",
        "| strong | poor_context | avoid chase; retest or skip |",
        "",
        "## Context Inputs To Add To EA Diagnostics",
        "",
        "- H4 wave-2 endpoint naturalness.",
        "- H1 counter N-wave break quality.",
        "- M15 pre-break extension.",
        "- Obstacle-free room from neckline to 2R.",
        "- Neckline age and excessive touch count.",
        "- SL ATR width.",
        "- 1R to 2R continuation room.",
        "",
        "## Guardrail",
        "",
        "The next implementation should first emit Context Quality labels and summary counters. It should not immediately route trades based on these labels.",
    ]
    OUTPUTS["next_router_notes"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog() -> None:
    text = f"""# 2026-06-15 - Nested N-Wave Context Quality Diagnostic

## Summary

- Compared 2025-10 removed `dirty`/`weak` winners against 2026-Q1 avoided `dirty`/`weak` losers.
- Added diagnostic-only `context_quality_v0` labels from existing Router audit columns.
- No EA behavior, routing logic, SL/TP, RewardR, timeframe, spread guard, risk calculation, or CTrade code changed.

## Evidence

- Summary: [reports/backtest/{OUTPUTS['summary'].name}](../../reports/backtest/{OUTPUTS['summary'].name})
- Candidate rows: [reports/backtest/{OUTPUTS['candidate_rows'].name}](../../reports/backtest/{OUTPUTS['candidate_rows'].name})
- Comparison CSV: [reports/backtest/{OUTPUTS['comparison'].name}](../../reports/backtest/{OUTPUTS['comparison'].name})
- Bucket matrix: [reports/backtest/{OUTPUTS['bucket_matrix'].name}](../../reports/backtest/{OUTPUTS['bucket_matrix'].name})
- Cohort diff: [reports/backtest/{OUTPUTS['cohort_diff'].name}](../../reports/backtest/{OUTPUTS['cohort_diff'].name})
- Next router notes: [reports/backtest/{OUTPUTS['next_router_notes'].name}](../../reports/backtest/{OUTPUTS['next_router_notes'].name})

## Decision

Router v2 threshold tuning is still premature. The next useful EA change is to emit a Context Quality diagnostic label before routing, then validate whether that label separates 2025-10 deleted winners from 2026-Q1 avoided losers.
"""
    DEVLOG.write_text(text, encoding="utf-8")


def main() -> None:
    rows = enrich(read_rows(IN_PATH))
    comparison = aggregate(rows, ["cohort"])
    comparison += aggregate(rows, ["cohort", "router_decision"])
    matrix = bucket_matrix(rows)
    diff = cohort_diff(rows)

    write_rows(OUTPUTS["candidate_rows"], rows)
    write_rows(OUTPUTS["comparison"], comparison)
    write_rows(OUTPUTS["bucket_matrix"], matrix)
    write_rows(OUTPUTS["cohort_diff"], diff)
    write_next_router_notes()
    write_summary(rows, comparison, diff)
    write_devlog()
    OUTPUTS["metrics"].write_text(
        json.dumps(
            {
                "rows": len(rows),
                "cohorts": Counter(str(row["cohort"]) for row in rows),
                "context_quality_v0": Counter(str(row["context_quality_v0"]) for row in rows),
                "outputs": {key: str(value) for key, value in OUTPUTS.items()},
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"rows": len(rows), "summary": str(OUTPUTS["summary"])}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
