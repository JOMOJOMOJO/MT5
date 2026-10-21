"""Exact fixtures for matching, clustered inference and multiplicity control."""
import numpy as np
import pandas as pd
import pytest

from tools.entry_research.baseline import MATCH_COLUMNS, matched_baseline
from tools.entry_research.statistics import METRICS, calendar_week_bootstrap, holm_adjust, summarize


def feature_fixture():
    rows = []
    for hour in [8, 16]:
        for i in range(10):
            rows.append({
                "symbol": "USDJPY", "year": 2024, "hour": hour, "weekday": 0,
                "vol_bucket": "normal", "eligible": True,
                "signal_index": hour * 100 + i, "entry_index": hour * 100 + i + 1,
                "signal_time": pd.Timestamp("2024-01-01") + pd.Timedelta(hours=hour, minutes=5 * i),
                "entry_time": pd.Timestamp("2024-01-01") + pd.Timedelta(hours=hour, minutes=5 * (i + 1)),
                "week": "2024-01-01", "atr14": 0.2,
            })
    return pd.DataFrame(rows)


def candidate_fixture(features):
    selected = features.iloc[[0, 1, 2, 10, 11]].copy()
    selected["candidate_id"] = [f"event_{i}" for i in range(len(selected))]
    selected["method"] = "ma_cross"
    selected["side"] = ["LONG", "LONG", "SHORT", "LONG", "SHORT"]
    return selected


def test_baseline_exact_counts_unique_within_stratum_and_reproducible():
    features = feature_fixture()
    candidates = candidate_fixture(features)
    controls, audit = matched_baseline(features, candidates, seed=23, repeats=4)
    keys = ["method", "side", *MATCH_COLUMNS]
    wanted = candidates.groupby(keys).size().sort_index()
    for replicate, sampled in controls.groupby("replicate"):
        pd.testing.assert_series_equal(sampled.groupby(keys).size().sort_index(), wanted)
        assert not sampled.duplicated(keys + ["signal_index"]).any()
    assert controls["candidate_id"].is_unique
    assert len(controls) == len(candidates) * 4
    assert audit["pool_n"].eq(10).all()
    assert audit["requested_n"].equals(audit["sampled_distinct_n"])
    shuffled, shuffled_audit = matched_baseline(
        features.sample(frac=1, random_state=8), candidates.sample(frac=1, random_state=9), seed=23, repeats=4
    )
    pd.testing.assert_frame_equal(controls, shuffled)
    pd.testing.assert_frame_equal(audit, shuffled_audit)


def test_baseline_does_not_relax_matching_or_use_ineligible_rows():
    features = feature_fixture()
    candidates = candidate_fixture(features)
    features.loc[features["hour"].eq(8), "eligible"] = False
    with pytest.raises(ValueError, match="Insufficient exact-match pool"):
        matched_baseline(features, candidates, seed=4)
    features = feature_fixture()
    features.loc[features["signal_index"].eq(800), "eligible"] = False
    controls, _ = matched_baseline(features, candidates, seed=4)
    assert 800 not in controls["signal_index"].to_list()


def test_original_event_bars_can_be_controls():
    features = feature_fixture().iloc[:1].copy()
    candidates = features.assign(candidate_id="event", method="ma_cross", side="LONG")
    controls, audit = matched_baseline(features, candidates, seed=42, repeats=2)
    assert controls["signal_index"].eq(800).all()
    assert audit["strategy_event_bars_sampled_n"].eq(1).all()


def bootstrap_fixture():
    strategy = pd.DataFrame({"week": ["w1", "w1", "w2"], "net_pips": [1.0, 3.0, 8.0]})
    controls = pd.DataFrame({
        "week": ["w1", "w1", "w2", "w1", "w1", "w2"],
        "replicate": [0, 0, 0, 1, 1, 1],
        "net_pips": [0.0, 2.0, 3.0, 2.0, 4.0, 6.0],
    })
    return strategy, controls


def test_calendar_bootstrap_aligns_weeks_and_uses_weighted_ratios():
    strategy, controls = bootstrap_fixture()
    boot = calendar_week_bootstrap(strategy, controls, np.random.default_rng(1), multiplicities=np.array([[2, 0], [0, 2], [1, 1]]))
    np.testing.assert_allclose(boot["strategy"], [2, 8, 4])
    np.testing.assert_allclose(boot["baseline"], [2, 4.5, 17 / 6])
    np.testing.assert_allclose(boot["difference"], [0, 3.5, 7 / 6])


def test_control_replicates_do_not_inflate_bootstrap_sample_size():
    strategy, controls = bootstrap_fixture()
    doubled = pd.concat([controls, controls.assign(replicate=controls["replicate"] + 2)])
    first = calendar_week_bootstrap(strategy, controls, np.random.default_rng(15), reps=50)
    second = calendar_week_bootstrap(strategy, doubled, np.random.default_rng(15), reps=50)
    for metric in ["strategy", "baseline", "difference"]:
        np.testing.assert_allclose(first[metric], second[metric])


def test_weekly_bootstrap_does_not_resample_individual_events():
    strategy = pd.DataFrame({"week": ["one_week"] * 100, "net_pips": np.arange(100)})
    controls = strategy.assign(replicate=0, net_pips=0)
    boot = calendar_week_bootstrap(strategy, controls, np.random.default_rng(2), reps=100)
    assert np.unique(boot["strategy"]).tolist() == [49.5]
    assert np.unique(boot["difference"]).tolist() == [49.5]


def test_holm_adjust_is_monotonic_and_reserves_missing_tests():
    np.testing.assert_allclose(holm_adjust([0.04, 0.001, 0.02]), [0.04, 0.003, 0.04])
    np.testing.assert_allclose(holm_adjust([0.01, np.nan, 0.02]), [0.03, np.nan, 0.04], equal_nan=True)
    np.testing.assert_allclose(holm_adjust([0.01], family_size=6), [0.06])
    with pytest.raises(ValueError):
        holm_adjust([1.1])
    with pytest.raises(ValueError):
        holm_adjust([0.1, 0.2], family_size=1)


def outcome_fixture(events, offset=0):
    rows = []
    for _, event in events.iterrows():
        for horizon in [3, 10]:
            value = float(event["entry_index"]) + offset
            rows.append({"candidate_id": event["candidate_id"], "horizon": horizon, "complete": True,
                         **{metric: value for metric in METRICS}})
    return pd.DataFrame(rows)


def test_summary_means_counts_nonoverlap_and_h10_only_inference():
    events = pd.DataFrame({
        "candidate_id": ["a", "b", "c"], "method": ["ma_cross"] * 3, "side": ["LONG"] * 3,
        "week": ["2024-01-01", "2024-01-01", "2024-01-08"], "entry_index": [0, 1, 10], "symbol": ["USDJPY"] * 3,
    })
    controls = pd.concat([
        events.assign(candidate_id=[f"{x}_{i}" for x in events["candidate_id"]], replicate=i)
        for i in range(2)
    ], ignore_index=True)
    result = summarize(outcome_fixture(events), events, outcome_fixture(controls, offset=-2), controls, seed=9, bootstrap_reps=99)
    row = result.loc[result["side"].eq("LONG") & result["horizon"].eq(10)].iloc[0]
    assert row["n_candidates"] == row["n_complete"] == 3
    assert row["n_baseline_complete_total"] == 6
    assert row["baseline_repeats"] == 2
    assert row["mean_net_pips"] == pytest.approx(11 / 3)
    assert row["delta_net_pips"] == pytest.approx(2)
    assert row["n_nonoverlap"] == 2
    assert row["n_overlapping"] == 1
    assert row["nonoverlap_mean_net_pips"] == 5
    assert row["delta_net_pips_ci_low"] == pytest.approx(2)
    assert row["delta_net_pips_ci_high"] == pytest.approx(2)
    assert row["holm_family_size"] == 6
    assert row["p_delta_net_pips"] == pytest.approx(0.01)
    assert row["p_delta_net_pips_holm"] == pytest.approx(0.06)
    assert row["thin_sample"]
    assert result.loc[result["horizon"].eq(3), "p_delta_net_pips"].isna().all()
    pd.testing.assert_frame_equal(result, summarize(outcome_fixture(events), events, outcome_fixture(controls, offset=-2), controls, seed=9, bootstrap_reps=99))


def test_incomplete_and_nonfinite_outcomes_are_not_silently_counted():
    features = feature_fixture()
    candidates = candidate_fixture(features)
    controls, _ = matched_baseline(features, candidates, seed=1, repeats=2)
    outcomes, baseline = outcome_fixture(candidates), outcome_fixture(controls)
    outcomes.loc[0, "complete"] = False
    outcomes.loc[0, METRICS] = np.nan
    result = summarize(outcomes, candidates, baseline, controls, seed=1, bootstrap_reps=5)
    row = result.loc[result["side"].eq("LONG") & result["horizon"].eq(3)].iloc[0]
    assert row["n_incomplete"] == 1
    assert row["n_complete"] == 2
    outcomes.loc[0, "complete"] = True
    with pytest.raises(ValueError, match="missing/non-finite"):
        summarize(outcomes, candidates, baseline, controls, seed=1, bootstrap_reps=5)
