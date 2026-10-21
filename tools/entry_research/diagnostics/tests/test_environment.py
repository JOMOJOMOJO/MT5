"""Frozen-cell enumeration, causal metadata and conservative sample gates."""
import numpy as np
import pandas as pd
import pytest

from tools.entry_research.diagnostics.environment import (
    CATEGORIES, CELLS_PER_METHOD_SIDE, cell_templates, environment_features, explore_environment,
)


def fixture_frames():
    events = pd.DataFrame({
        "candidate_id": ["a", "b", "c", "d"], "method": ["ema_cross"] * 4, "side": ["LONG"] * 4,
        "week": ["2024-01-01", "2024-01-08", "2025-01-06", "2025-01-13"], "year": [2024, 2024, 2025, 2025],
        "hour": [1] * 4, "vol_bucket": ["normal"] * 4, "range_position": [.4] * 4,
        "cloud_position": ["above"] * 4, "h1_trend": ["up"] * 4, "m15_trend": ["up"] * 4,
        "h1_stale": [False] * 4, "m15_stale": [False] * 4, "eligible": [True] * 4,
    })
    controls = pd.concat([events.assign(candidate_id=[f"{event}_{rep}" for event in events.candidate_id], replicate=rep)
                          for rep in range(10)], ignore_index=True)
    outcomes = pd.DataFrame({"candidate_id": events.candidate_id, "horizon": 10, "complete": True,
                             "gross_pips": 6.9, "net_pips": 5.0})
    baseline = pd.DataFrame({"candidate_id": controls.candidate_id, "horizon": 10, "complete": True,
                             "gross_pips": 2.9, "net_pips": 1.0})
    config = {"methods": ["ema_cross", "ichimoku_cloud", "kijun_bounce"], "min_n": 4, "min_weeks": 4,
              "peryear_min_n": 2, "peryear_weeks": 2, "baseline_repeats": 10,
              "bootstrap_reps": 20, "seed": 20261015, "cell_cap": 732}
    return events, controls, outcomes, baseline, config


def select(result, condition="h1_alignment=aligned"):
    return result.loc[result.method.eq("ema_cross") & result.side.eq("LONG") & result.condition.eq(condition)].iloc[0]


def test_full_cell_family_is_fixed_and_zero_cells_are_visible():
    events, controls, outcomes, baseline, config = fixture_frames()
    config.update(min_n=200, min_weeks=30, peryear_min_n=75, peryear_weeks=15)
    templates = cell_templates()
    assert CELLS_PER_METHOD_SIDE == len(templates) == 122
    assert {n: sum(len(dims) == n for dims, _ in templates) for n in [1, 2, 3]} == {1: 20, 2: 39, 3: 63}
    result = explore_environment(events, controls, outcomes, baseline, config)
    assert len(result) == 732
    assert result.cell_id.is_unique
    assert result.groupby(["method", "side"]).size().eq(122).all()
    assert result.loc[result.method.ne("ema_cross"), "n"].eq(0).all()
    assert result.total_cells.eq(732).all() and result.holm_family_size.eq(732).all()
    assert result.attrs["count"] == result.attrs["cap"] == 732
    assert result.insufficient_sample.all()
    assert not result.exploratory_hypothesis.any()
    assert result.net_ci_low.isna().all() and result.p_delta_net_pips.isna().all()
    config["cell_cap"] = 731
    with pytest.raises(ValueError, match="above cap"):
        explore_environment(events, controls, outcomes, baseline, config)


def test_category_boundaries_and_stale_direction_are_explicit():
    events, *_ = fixture_frames()
    events["range_position"] = [-1., .5, .500001, np.nan]
    events["hour"] = [0, 6, 12, 23]
    events["side"] = ["LONG", "SHORT", "LONG", "SHORT"]
    events["h1_trend"] = ["up", "down", "up", "flat"]
    events["h1_stale"] = [False, False, True, False]
    events["cloud_position"] = ["above", "above", "inside", "unknown"]
    enriched = environment_features(events)
    assert enriched.range_bucket.tolist() == ["range_low", "range_low", "range_high", "unknown"]
    assert enriched.hour_block.tolist() == list(CATEGORIES["hour_block"])
    assert enriched.h1_alignment.tolist() == ["aligned", "aligned", "other", "other"]
    assert enriched.cloud_alignment.tolist() == ["aligned", "opposed", "inside", "unknown"]


def test_shuffled_rows_and_unrelated_future_metadata_do_not_change_results():
    events, controls, outcomes, baseline, config = fixture_frames()
    config["min_n"] = 200
    expected = explore_environment(events, controls, outcomes, baseline, config)
    changed_events = events.assign(future_close=1e10, future_winner=True, realized_exit=9e30).sample(frac=1, random_state=2)
    changed_controls = controls.assign(future_close=-1e10, future_winner=False).sample(frac=1, random_state=3)
    got = explore_environment(changed_events, changed_controls, outcomes.sample(frac=1, random_state=4),
                              baseline.sample(frac=1, random_state=5), config)
    pd.testing.assert_frame_equal(expected, got)


def test_each_calendar_year_must_pass_its_own_sample_gate():
    events, controls, outcomes, baseline, config = fixture_frames()
    events.loc[events.candidate_id.eq("c"), ["year", "week"]] = [2024, "2024-01-15"]
    controls.loc[controls.candidate_id.str.startswith("c_"), ["year", "week"]] = [2024, "2024-01-15"]
    row = select(explore_environment(events, controls, outcomes, baseline, config))
    assert row.n == 4 and row.weeks == 4
    assert row.n_2024 == 3 and row.n_2025 == 1
    assert not row.sample_gates_pass and "n_2025<2" in row.sample_gate_reasons
    assert np.isnan(row.net_ci_low) and np.isnan(row.p_delta_net_pips)
    assert not row.exploratory_hypothesis


def test_control_replicates_are_gated_individually_and_conditioning_is_labelled():
    events, controls, outcomes, baseline, config = fixture_frames()
    controls.loc[controls.candidate_id.eq("a_9"), "h1_trend"] = "down"
    row = select(explore_environment(events, controls, outcomes, baseline, config))
    assert row.n == 4 and row.baseline_n_total == 39
    assert row.baseline_n_min == 3 and row.baseline_n_max == 4
    assert row.baseline_represented_repeats == 10
    assert row.baseline_mean_net_pips == 1
    assert row.baseline_estimator == "mean_of_replicate_conditional_means"
    assert not row.environment_rematched
    assert not row.sample_gates_pass and "baseline_n_min<4" in row.sample_gate_reasons
    assert np.isnan(row.delta_ci_low)


def test_baseline_mean_weights_replicates_equally_not_pooled_event_count():
    events, controls, outcomes, baseline, config = fixture_frames()
    controls.loc[controls.replicate.eq(0) & controls.candidate_id.ne("a_0"), "h1_trend"] = "down"
    baseline.loc[baseline.candidate_id.eq("a_0"), "net_pips"] = 11
    config["min_n"] = 200
    row = select(explore_environment(events, controls, outcomes, baseline, config))
    assert row.baseline_n_total == 37
    assert row.baseline_mean_net_pips == pytest.approx(2)
    assert row.baseline_mean_net_pips != pytest.approx((11 + 36) / 37)


def test_positive_fixture_must_pass_frozen_full_family_holm_and_annual_gates():
    events, controls, outcomes, baseline, config = fixture_frames()
    config["bootstrap_reps"] = 20000
    result = explore_environment(events, controls, outcomes, baseline, config)
    row = select(result)
    assert row.sample_gates_pass and row.annual_positive_both and row.annual_delta_positive_both
    assert row.mean_net_pips == row.net_ci_low == row.net_ci_high == 5
    assert row.delta_net_pips == row.delta_ci_low == row.delta_ci_high == 4
    assert row.p_delta_net_pips == pytest.approx(1 / 20001)
    assert row.p_delta_net_pips_holm == pytest.approx(732 / 20001)
    assert not row.resolution_limited and row.exploratory_hypothesis
    assert result.loc[result.insufficient_sample, "p_delta_net_pips_holm"].isna().all()
    assert not result.loc[result.insufficient_sample, "exploratory_hypothesis"].any()


def test_insufficient_bootstrap_resolution_is_explicit_not_a_discovery():
    events, controls, outcomes, baseline, config = fixture_frames()
    config["bootstrap_reps"] = 1000
    row = select(explore_environment(events, controls, outcomes, baseline, config))
    assert row.sample_gates_pass and row.resolution_limited
    assert row.minimum_holm_p == pytest.approx(732 / 1001)
    assert not row.exploratory_hypothesis


def test_original_count_or_outcome_contract_failure_is_not_hidden():
    events, controls, outcomes, baseline, config = fixture_frames()
    with pytest.raises(ValueError, match="exactly the supplied candidate cohort"):
        explore_environment(events, controls, outcomes.iloc[:-1], baseline, config)
    with pytest.raises(ValueError, match="Original baseline count"):
        explore_environment(events, controls.iloc[:-1], outcomes, baseline.iloc[:-1], config)
    with pytest.raises(ValueError, match="H10"):
        explore_environment(events, controls, outcomes.assign(horizon=20), baseline, config)
    with pytest.raises(ValueError, match="2024/2025"):
        explore_environment(events.assign(year=2026), controls, outcomes, baseline, config)
