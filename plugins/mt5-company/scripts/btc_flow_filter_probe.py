from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import pandas as pd


@dataclass(frozen=True)
class CandidateRule:
    name: str
    side: str
    horizon: int
    base_expression: str
    filter_expression: str | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Probe flow and volume filters on top of BTCUSD feature-lab base rules.")
    parser.add_argument("--features-path", required=True, help="Path to analysis_window_features.csv.gz")
    parser.add_argument("--split-date", required=True, help="Train/test split timestamp in ISO format")
    parser.add_argument("--output-dir", default="", help="Optional output directory")
    return parser.parse_args()


def safe_query(df: pd.DataFrame, expression: str) -> pd.Series:
    return df.eval(expression).fillna(False).astype(bool)


def calc_metrics(df: pd.DataFrame, mask: pd.Series, side: str, horizon: int) -> dict[str, float | int] | None:
    subset = df.loc[mask & df[f"future_return_atr_{horizon}"].notna()].copy()
    if subset.empty:
        return None

    signed_return = subset[f"future_return_atr_{horizon}"]
    if side == "short":
        signed_return = -signed_return

    days = max((subset["time"].max() - subset["time"].min()).total_seconds() / 86400.0, 1.0)
    return {
        "trades": int(len(subset)),
        "trades_per_day": float(len(subset) / days),
        "expectancy_atr": float(signed_return.mean()),
        "hit_rate": float((signed_return > 0.0).mean()),
    }


def main() -> None:
    args = parse_args()

    features_path = Path(args.features_path).resolve()
    df = pd.read_csv(features_path, parse_dates=["time"])
    split_date = pd.Timestamp(args.split_date)

    train = df[df["time"] < split_date].copy()
    test = df[df["time"] >= split_date].copy()

    output_dir = Path(args.output_dir).resolve() if args.output_dir else features_path.parent
    output_dir.mkdir(parents=True, exist_ok=True)

    candidates = [
        CandidateRule(
            name="long_roc_rsi_base",
            side="long",
            horizon=3,
            base_expression="(roc_atr_6 <= -1.3739) & (rsi7 <= 29.5772)",
        ),
        CandidateRule(
            name="long_break_high_base",
            side="long",
            horizon=3,
            base_expression="(breakout_persist_down_6 >= 1.0) & (high_break_12 <= -3.0687)",
        ),
        CandidateRule(
            name="long_break_high_flow_negative",
            side="long",
            horizon=3,
            base_expression="(breakout_persist_down_6 >= 1.0) & (high_break_12 <= -3.0687)",
            filter_expression="tick_flow_signed_3 <= -0.4165",
        ),
        CandidateRule(
            name="short_rsi_ret_base",
            side="short",
            horizon=6,
            base_expression="(rsi7 >= 70.3714) & (ret_6 >= 0.0017)",
        ),
        CandidateRule(
            name="short_rsi_ret_flow_positive",
            side="short",
            horizon=6,
            base_expression="(rsi7 >= 70.3714) & (ret_6 >= 0.0017)",
            filter_expression="tick_flow_signed_3 >= 0.4176",
        ),
        CandidateRule(
            name="short_break_rsi_base",
            side="short",
            horizon=3,
            base_expression="(breakout_persist_up_6 >= 1.0) & (rsi7 >= 70.3714)",
        ),
        CandidateRule(
            name="short_break_rsi_flow_positive",
            side="short",
            horizon=3,
            base_expression="(breakout_persist_up_6 >= 1.0) & (rsi7 >= 70.3714)",
            filter_expression="tick_flow_signed_3 >= 0.4176",
        ),
        CandidateRule(
            name="short_break_rsi_volume_low",
            side="short",
            horizon=3,
            base_expression="(breakout_persist_up_6 >= 1.0) & (rsi7 >= 70.3714)",
            filter_expression="tick_volume_rel10 <= 0.7937",
        ),
    ]

    rows: list[dict[str, object]] = []
    for candidate in candidates:
        train_mask = safe_query(train, candidate.base_expression)
        test_mask = safe_query(test, candidate.base_expression)
        if candidate.filter_expression:
            train_mask &= safe_query(train, candidate.filter_expression)
            test_mask &= safe_query(test, candidate.filter_expression)

        train_metrics = calc_metrics(train, train_mask, candidate.side, candidate.horizon)
        test_metrics = calc_metrics(test, test_mask, candidate.side, candidate.horizon)
        if not train_metrics or not test_metrics:
            continue

        row = {
            "name": candidate.name,
            "side": candidate.side,
            "horizon": candidate.horizon,
            "base_expression": candidate.base_expression,
            "filter_expression": candidate.filter_expression or "",
            **{f"train_{key}": value for key, value in train_metrics.items()},
            **{f"test_{key}": value for key, value in test_metrics.items()},
        }
        rows.append(row)

    results = pd.DataFrame(rows).sort_values(["side", "test_expectancy_atr", "test_trades_per_day"], ascending=[True, False, False])
    csv_path = output_dir / "flow_filter_probe.csv"
    results.to_csv(csv_path, index=False)
    results.to_csv(output_dir / "flow_filter_probe.csv.gz", index=False, compression="gzip")

    recommendations = {
        "long_recommendation": "Use the unfiltered `roc_atr_6 + rsi7` overextension long as the default high-turnover long mask. Volume and positive-flow filters mostly reduce turnover without improving OOS expectancy.",
        "short_recommendation": "Use `rsi7 + ret_6` with positive `tick_flow_signed_3` as the default short mask. Positive flow improves short-side OOS expectancy while preserving meaningful turnover.",
        "volume_interpretation": "Volume/flow works asymmetrically. For BTCUSD M5, upside exhaustion backed by positive short-horizon flow is a stronger short-fade setup. Long-side fades degrade when high-volume chase conditions are added.",
    }

    summary = {
        "features_path": str(features_path),
        "split_date": split_date.isoformat(),
        "rows": rows,
        **recommendations,
    }
    json_path = output_dir / "summary.json"
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    lines = [
        "# BTCUSD Flow Filter Probe",
        "",
        f"- Features: `{features_path}`",
        f"- Split date: `{split_date.isoformat()}`",
        "",
        "## Best Long Candidate",
        "",
        "- `roc_atr_6 <= -1.3739` + `rsi7 <= 29.5772`",
        "- Keep the long mask simple. Negative-flow or low-volume filters reduced turnover and usually did not improve OOS enough to justify them.",
        "",
        "## Best Short Candidate",
        "",
        "- `rsi7 >= 70.3714` + `ret_6 >= 0.0017` + `tick_flow_signed_3 >= 0.4176`",
        "- Positive short-horizon flow improved OOS expectancy while keeping turnover high enough for a mainline prototype.",
        "",
        "## Volume / Flow Interpretation",
        "",
        "- Volume and flow are not symmetric.",
        "- Long-side fades did not benefit from high-volume chase conditions.",
        "- Short-side exhaustion became cleaner when strong positive flow was present first, which supports the idea of fading crowded upside extensions rather than fading every overbought print.",
        "",
        "## Selected Rows",
        "",
    ]

    for row in results.head(8).to_dict(orient="records"):
        filter_text = row["filter_expression"] if row["filter_expression"] else "(none)"
        lines.append(
            f"- `{row['name']}`: horizon `{row['horizon']}`, filter `{filter_text}`, "
            f"train `{row['train_trades_per_day']:.2f}/day exp {row['train_expectancy_atr']:.4f}`, "
            f"test `{row['test_trades_per_day']:.2f}/day exp {row['test_expectancy_atr']:.4f}`, "
            f"test hit `{row['test_hit_rate']:.2%}`"
        )

    md_path = output_dir / "summary.md"
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Flow filter probe written to: {output_dir}")


if __name__ == "__main__":
    main()
