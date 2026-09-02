#!/usr/bin/env python3
"""Independent consistency oracle for the Step 15I compact evidence."""
from __future__ import annotations

from bisect import insort
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "reports/analysis/tick_shock/step15i"
MIN_HISTORY = 100


def main() -> None:
    data = pd.read_csv(OUT / "episode_direction_dataset.csv", low_memory=False)
    results = []

    def check(name: str, actual: int | float, expected: int | float) -> None:
        results.append({"check": name, "actual": actual, "expected": expected, "status": "PASS" if actual == expected else "FAIL"})

    check("episode_rows", len(data), 3151)
    check("duplicate_episode_id", int(data.episode_id.duplicated().sum()), 0)
    check("analysis_eligible", int(data.analysis_eligible.sum()), 1675)
    check("quantile_ready", int((data.analysis_eligible & data.quantile_ready).sum()), 1175)
    check("high_movement", int(data.high_movement_filter.sum()), 48)
    check("high_movement_clusters", data.loc[data.high_movement_filter, "market_cluster_id"].nunique(), 48)
    predicate = data.quantile_ready & data.spread_atr_ratio.le(data.spread_atr_threshold) & data.tick_activity.ge(data.tick_activity_threshold) & data.atr14_m5.ge(data.atr_threshold)
    check("filter_predicate_mismatch", int((predicate != data.high_movement_filter).sum()), 0)
    check("feature_quote_after_processing", int((data.quote_msc > data.processing_msc).fillna(False).sum()), 0)

    selected = data[data.high_movement_filter]
    counts = selected.direction_label.value_counts()
    check("continuation_labels", int(counts.get("CONTINUATION", 0)), 11)
    check("reversal_labels", int(counts.get("REVERSAL", 0)), 9)
    check("neutral_labels", int(counts.get("NEUTRAL_TIMEOUT", 0)), 28)
    check("ambiguous_labels", int(counts.get("AMBIGUOUS_SAME_MSC", 0)), 0)

    # Rebuild the exact expanding histories independently for all ready rows.
    mismatches = 0
    eligible = data[data.analysis_eligible].sort_values(["timestamp_msc", "market_cluster_id", "episode_id"])
    for _, group in eligible.groupby("symbol", sort=False):
        histories = {"spread_atr_ratio": [], "tick_activity": [], "atr14_m5": []}
        for row in group.itertuples(index=False):
            if row.quantile_ready:
                expected = (
                    float(np.quantile(histories["spread_atr_ratio"], .30)),
                    float(np.quantile(histories["tick_activity"], .70)),
                    float(np.quantile(histories["atr14_m5"], .70)),
                )
                actual = (row.spread_atr_threshold, row.tick_activity_threshold, row.atr_threshold)
                mismatches += int(not np.allclose(actual, expected, rtol=0, atol=1e-12))
            for feature, values in histories.items():
                value = getattr(row, feature)
                if pd.notna(value):
                    insort(values, float(value))
    check("causal_threshold_rebuild_mismatch", mismatches, 0)

    required = {
        "population_funnel.csv", "direction_label_counts.csv", "feature_summary.csv", "feature_bin_comparison.csv",
        "continuation_vs_reversal_feature_comparison.csv", "candidate_hypothesis_comparison.csv", "high_movement_validation.csv",
    }
    check("missing_required_outputs", len([name for name in required if not (OUT / name).exists()]), 0)

    result = pd.DataFrame(results)
    result.to_csv(OUT / "independent_oracle.csv", index=False)
    if result.status.ne("PASS").any():
        raise SystemExit(result[result.status.ne("PASS")].to_string(index=False))


if __name__ == "__main__":
    main()
