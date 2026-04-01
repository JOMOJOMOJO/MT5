from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import numpy as np
import pandas as pd


RULE_PREFIX_RE = re.compile(r"^[^:]+:")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Re-rank BTCUSD feature-lab rules with broker spread costs applied.")
    parser.add_argument("--features-path", required=True, help="Path to analysis_window_features.csv.gz")
    parser.add_argument("--single-rules-path", required=True, help="Path to single_feature_rules.csv or .csv.gz")
    parser.add_argument("--pair-rules-path", required=True, help="Path to pair_feature_rules.csv or .csv.gz")
    parser.add_argument("--split-date", required=True, help="Train/test split timestamp in ISO format")
    parser.add_argument("--output-dir", required=True, help="Directory for spread-aware outputs")
    parser.add_argument("--cost-quantile", type=float, default=0.75, help="Spread quantile used as the conservative cost floor")
    parser.add_argument("--min-test-expectancy", type=float, default=0.25, help="Minimum raw OOS expectancy to consider promotable")
    parser.add_argument("--min-net-edge", type=float, default=0.0, help="Minimum net edge after the spread cost floor")
    return parser.parse_args()


def infer_point(frame: pd.DataFrame) -> float:
    if "symbol_point" in frame.columns:
        valid = frame["symbol_point"].dropna()
        if not valid.empty and float(valid.median()) > 0.0:
            return float(valid.median())

    decimals = 0
    sample = frame["close"].dropna().astype(float).head(500)
    for value in sample:
        text = f"{value:.8f}".rstrip("0")
        if "." in text:
            decimals = max(decimals, len(text.split(".")[1]))
    return 10 ** (-decimals) if decimals > 0 else 1.0


def normalized_spread_atr(frame: pd.DataFrame) -> pd.Series:
    if "spread_atr" in frame.columns:
        spread_atr = pd.to_numeric(frame["spread_atr"], errors="coerce")
        median = spread_atr.replace([np.inf, -np.inf], np.nan).dropna().median()
        if pd.notna(median) and median < 10.0:
            return spread_atr

    point = infer_point(frame)
    spread_points = pd.to_numeric(frame.get("spread_points", frame.get("spread")), errors="coerce")
    atr = pd.to_numeric(frame["atr14"], errors="coerce").replace(0.0, np.nan)
    return (spread_points * point) / atr


def safe_eval(frame: pd.DataFrame, expression: str) -> pd.Series:
    return frame.eval(expression).fillna(False).astype(bool)


def single_expression(row: pd.Series) -> str:
    return f"({row['feature']} {row['operator']} {row['threshold']})"


def normalize_rule_text(text: str) -> str:
    stripped = RULE_PREFIX_RE.sub("", text).strip()
    return f"({stripped})"


def spread_metrics(frame: pd.DataFrame, mask: pd.Series, cost_quantile: float) -> tuple[float, float, int]:
    values = frame.loc[mask, "spread_atr_norm"].replace([np.inf, -np.inf], np.nan).dropna()
    if values.empty:
        return float("nan"), float("nan"), 0
    return float(values.mean()), float(values.quantile(cost_quantile)), int(len(values))


def build_single_rows(
    rules: pd.DataFrame,
    test_frame: pd.DataFrame,
    cost_quantile: float,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for _, row in rules.iterrows():
        expr = single_expression(row)
        mask = safe_eval(test_frame, expr)
        spread_mean, spread_floor, spread_count = spread_metrics(test_frame, mask, cost_quantile)
        if spread_count == 0:
            continue
        rows.append(
            {
                "kind": "single",
                "side": row["side"],
                "context": row["context"],
                "horizon": int(row["horizon"]),
                "expression": expr,
                "test_trades": int(row["test_trades"]),
                "test_tpd": float(row["test_tpd"]),
                "test_expectancy": float(row["test_expectancy"]),
                "test_hit_rate": float(row["test_hit_rate"]),
                "test_spread_mean_atr": spread_mean,
                "test_spread_floor_atr": spread_floor,
                "test_net_mean_after_spread": float(row["test_expectancy"]) - spread_mean,
                "test_net_floor_after_spread": float(row["test_expectancy"]) - spread_floor,
            }
        )
    return rows


def build_pair_rows(
    rules: pd.DataFrame,
    test_frame: pd.DataFrame,
    cost_quantile: float,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for _, row in rules.iterrows():
        expr = f"{normalize_rule_text(row['rule_a'])} & {normalize_rule_text(row['rule_b'])}"
        mask = safe_eval(test_frame, expr)
        spread_mean, spread_floor, spread_count = spread_metrics(test_frame, mask, cost_quantile)
        if spread_count == 0:
            continue
        rows.append(
            {
                "kind": "pair",
                "side": row["side"],
                "context": row["context"],
                "horizon": int(row["horizon"]),
                "expression": expr,
                "rule_a": row["rule_a"],
                "rule_b": row["rule_b"],
                "test_trades": int(row["test_trades"]),
                "test_tpd": float(row["test_tpd"]),
                "test_expectancy": float(row["test_expectancy"]),
                "test_hit_rate": float(row["test_hit_rate"]),
                "test_spread_mean_atr": spread_mean,
                "test_spread_floor_atr": spread_floor,
                "test_net_mean_after_spread": float(row["test_expectancy"]) - spread_mean,
                "test_net_floor_after_spread": float(row["test_expectancy"]) - spread_floor,
            }
        )
    return rows


def top_rows_text(frame: pd.DataFrame, limit: int) -> list[str]:
    if frame.empty:
        return ["- No rule cleared the current spread-aware gate."]
    lines: list[str] = []
    for row in frame.head(limit).to_dict(orient="records"):
        label = row["expression"] if row["kind"] == "single" else f"{row['rule_a']} + {row['rule_b']}"
        lines.append(
            f"- `{label}` horizon `{int(row['horizon'])}`: "
            f"test `{row['test_tpd']:.2f}/day exp {row['test_expectancy']:.4f}`, "
            f"spread floor `{row['test_spread_floor_atr']:.4f}`, "
            f"net `{row['test_net_floor_after_spread']:.4f}`"
        )
    return lines


def main() -> int:
    args = parse_args()

    features_path = Path(args.features_path).resolve()
    single_rules_path = Path(args.single_rules_path).resolve()
    pair_rules_path = Path(args.pair_rules_path).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    features = pd.read_csv(features_path, parse_dates=["time"])
    features["spread_atr_norm"] = normalized_spread_atr(features)
    split_date = pd.Timestamp(args.split_date)
    test_frame = features.loc[features["time"] >= split_date].copy()

    single_rules = pd.read_csv(single_rules_path)
    pair_rules = pd.read_csv(pair_rules_path)

    spread_values = test_frame["spread_atr_norm"].replace([np.inf, -np.inf], np.nan).dropna()
    global_spread = {
        "mean": float(spread_values.mean()),
        "median": float(spread_values.median()),
        "p75": float(spread_values.quantile(0.75)),
        "p90": float(spread_values.quantile(0.90)),
    }

    rows = build_single_rows(single_rules, test_frame, args.cost_quantile) + build_pair_rows(pair_rules, test_frame, args.cost_quantile)
    ranked = pd.DataFrame(rows)
    ranked = ranked.sort_values(
        ["test_net_floor_after_spread", "test_expectancy", "test_tpd"],
        ascending=[False, False, False],
    ).reset_index(drop=True)

    promotable = ranked[
        (ranked["test_expectancy"] >= args.min_test_expectancy)
        & (ranked["test_net_floor_after_spread"] >= args.min_net_edge)
    ].copy()

    ranked.to_csv(output_dir / "spread_aware_rules.csv", index=False)
    ranked.to_csv(output_dir / "spread_aware_rules.csv.gz", index=False, compression="gzip")
    promotable.to_csv(output_dir / "spread_aware_promotable.csv", index=False)
    promotable.to_csv(output_dir / "spread_aware_promotable.csv.gz", index=False, compression="gzip")

    summary = {
        "features_path": str(features_path),
        "single_rules_path": str(single_rules_path),
        "pair_rules_path": str(pair_rules_path),
        "split_date": split_date.isoformat(),
        "cost_quantile": args.cost_quantile,
        "min_test_expectancy": args.min_test_expectancy,
        "min_net_edge": args.min_net_edge,
        "global_spread_atr": global_spread,
        "ranked_rule_count": int(len(ranked)),
        "promotable_rule_count": int(len(promotable)),
    }
    (output_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# BTCUSD Spread-Aware Re-Rank",
        "",
        f"- Features: `{features_path}`",
        f"- Split date: `{split_date.isoformat()}`",
        f"- Cost floor quantile: `{args.cost_quantile:.2f}`",
        "",
        "## Broker Spread Floor",
        "",
        f"- mean `{global_spread['mean']:.4f} ATR`",
        f"- median `{global_spread['median']:.4f} ATR`",
        f"- p75 `{global_spread['p75']:.4f} ATR`",
        f"- p90 `{global_spread['p90']:.4f} ATR`",
        "",
        "## Promotable Rules",
        "",
    ]
    lines.extend(top_rows_text(promotable, 10))
    lines.extend(["", "## Top Ranked Rules", ""])
    lines.extend(top_rows_text(ranked, 10))
    lines.extend(["", "## Verdict", ""])
    if promotable.empty:
        lines.append("- No current BTCUSD M5 rule clears the spread-aware gate on this broker.")
        lines.append("- The next mainline should require larger move size, slower context, or both before another actual MT5 prototype.")
    else:
        lines.append("- Open the next actual MT5 prototype only from the promotable rules above.")
    (output_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Spread-aware re-rank written to: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
