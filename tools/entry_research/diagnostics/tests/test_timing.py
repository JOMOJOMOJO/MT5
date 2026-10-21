import numpy as np
import pandas as pd
import pytest

from tools.entry_research.diagnostics.timing import POLICIES, evaluate_timing


def setup(side="LONG", count=100):
    times = np.arange(count, dtype=np.int64) * 300
    bars = pd.DataFrame({"time": times, "available_time": times + 300,
                         "open": 100., "high": 100.1, "low": 99.9, "close": 100.})
    candidates = pd.DataFrame({"candidate_id": ["origin"], "method": ["fixture"], "side": [side],
        "signal_index": [19], "entry_index": [20], "signal_time": [6000],
        "nominal_close_time": [6000], "entry_time": [6000], "atr14": [1.],
        "eligible": [True], "week": ["2024-01-01"], "year": [2024]})
    config = {"timeframe_seconds": 300, "pip_size": .01, "max_entry_delay_seconds": 300,
              "end_exclusive": 30000, "clock_basis": "source_clock",
              "cost": {"mode": "assumed", "spread_pips": 1.5,
                       "commission_pips_roundtrip": 0., "slippage_pips_per_side": .2}}
    return bars, candidates, config


def by_policy(bars, candidates, config):
    return evaluate_timing(bars, candidates, config).set_index("policy")


def test_all_origins_survive_and_fixed_waits_use_original_base():
    bars, candidates, config = setup()
    out = by_policy(bars, candidates, config)
    assert list(out.index) == list(POLICIES)
    for policy, index in [("immediate", 20), ("wait1", 21), ("wait3", 23), ("wait5", 25)]:
        row = out.loc[policy]
        assert row.status == "filled"
        assert row.fill_index == index
        assert row.wait_bars == index - 20
        assert row.endpoint_time_hold10 == (index + 10) * 300
        assert row.endpoint_time_deadline50 == 70 * 300
        assert row.net_hold10 == pytest.approx(-1.9)
        assert row.net_deadline50 == pytest.approx(-1.9)


def test_timeout_is_zero_opportunity_not_zero_conditional_profit():
    bars, candidates, config = setup()
    out = by_policy(bars, candidates, config)
    for policy in ("pullback", "breakout"):
        row = out.loc[policy]
        assert row.status == "expired"
        assert np.isnan(row.net_hold10)
        assert row.opp_net_hold10 == 0
        assert row.opp_net_deadline50 == 0
        assert np.isnan(row.conditional_cost_pips)
    assert (out.origin_candidate_id == "origin").all()


@pytest.mark.parametrize("side,sign", [("LONG", 1), ("SHORT", -1)])
def test_pullback_requires_later_reclaim_and_favorable_body(side, sign):
    bars, candidates, config = setup(side)
    # First touch closes across P0; the same candle cannot confirm a fill.
    bars.loc[20, ["open", "high", "low", "close"]] = [100, 100.4, 99.6, 100 + sign * .2]
    bars.loc[21, "close"] = 100 - sign * .05
    bars.loc[22, ["open", "high", "low", "close"]] = [100 - sign * .03, 100.3, 99.7, 100 + sign * .2]
    row = by_policy(bars, candidates, config).loc["pullback"]
    assert row.status == "filled"
    assert row.touch_index == 20
    assert row.confirmation_index == 22
    assert row.fill_index == 23
    assert row.confirmation_time == 23 * 300


def test_touch_same_bar_does_not_reclaim_without_later_crossing():
    bars, candidates, config = setup()
    bars.loc[20:29, ["open", "high", "low", "close"]] = [100, 100.4, 99.6, 100.2]
    row = by_policy(bars, candidates, config).loc["pullback"]
    assert row.touch_index == 20
    assert row.status == "expired"


@pytest.mark.parametrize("side,sign", [("LONG", 1), ("SHORT", -1)])
def test_breakout_uses_frozen_signal_window_including_signal(side, sign):
    bars, candidates, config = setup(side)
    bars.loc[19, ["high", "low"]] = [100.5, 99.5]
    # A later high/low cannot move the reference away from the original level.
    bars.loc[20, ["high", "low"]] = [102, 98]
    bars.loc[21, ["open", "high", "low", "close"]] = [100, 100.7, 99.3, 100 + sign * .6]
    row = by_policy(bars, candidates, config).loc["breakout"]
    assert row.status == "filled"
    assert row.trigger_level == 100 + sign * .5
    assert row.confirmation_index == 21
    assert row.fill_index == 22


def test_confirmation_availability_requires_next_actual_open_and_latency_cap():
    bars, candidates, config = setup()
    bars.loc[20, ["high", "close"]] = [100.5, 100.3]
    bars.loc[20, "available_time"] += 2
    row = by_policy(bars, candidates, config).loc["breakout"]
    assert row.status == "filled"
    assert row.confirmation_time == 6302
    assert row.fill_time == 6600
    # Keep the source availability monotone despite a delayed observation.
    bars.loc[20, "available_time"] = 6601
    bars.loc[21, "available_time"] = 6601
    row = by_policy(bars, candidates, config).loc["breakout"]
    assert row.status == "unexecutable"
    assert row.status_reason == "confirmation_entry_delay_exceeded"
    assert row.opp_net_hold10 == 0


def test_latest_observation_with_small_delay_can_fill_at_base_plus_eleven():
    bars, candidates, config = setup()
    bars.loc[29, ["high", "close"]] = [100.5, 100.3]
    bars.loc[29, "available_time"] += 2
    row = by_policy(bars, candidates, config).loc["breakout"]
    assert row.fill_index == 31
    assert row.wait_bars == 11


def test_missing_wait_data_is_unknown_never_zero_opportunity():
    bars, candidates, config = setup()
    bars = bars.drop(index=22).reset_index(drop=True)
    out = by_policy(bars, candidates, config)
    assert out.loc["immediate", "status"] == "filled"
    assert not out.loc["immediate", "endpoint_complete_hold10"]
    assert np.isnan(out.loc["immediate", "opp_net_hold10"])
    for policy in ("wait3", "wait5", "pullback", "breakout"):
        assert out.loc[policy, "status"] == "data_unavailable"
        assert np.isnan(out.loc[policy, "opp_net_hold10"])


def test_future_mutation_does_not_change_fill_decisions_or_timeout():
    bars, candidates, config = setup()
    bars.loc[20, ["high", "close"]] = [100.5, 100.3]
    original = evaluate_timing(bars, candidates, config)
    bars.loc[32:, ["open", "high", "low", "close"]] += 500
    mutated = evaluate_timing(bars, candidates, config)
    columns = ["origin_candidate_id", "policy", "status", "status_reason", "fill_index", "fill_time",
               "confirmation_index", "confirmation_time", "touch_index", "wait_bars"]
    pd.testing.assert_frame_equal(original[columns], mutated[columns])


def test_mutating_execution_bar_hlc_cannot_change_scheduled_fill():
    bars, candidates, config = setup()
    before = by_policy(bars, candidates, config)
    bars.loc[25, ["high", "low", "close"]] = [np.nan, np.nan, np.nan]
    after = by_policy(bars, candidates, config)
    assert before.loc["wait5", "status"] == after.loc["wait5", "status"] == "filled"
    assert before.loc["wait5", "fill_index"] == after.loc["wait5", "fill_index"]
    assert not after.loc["wait5", "endpoint_complete_hold10"]


def test_frozen_atr_and_direction_adjusted_returns():
    bars, candidates, config = setup()
    candidates["atr14"] = 2.
    bars["atr14"] = 999.
    bars.loc[29, ["high", "close"]] = [101, 101]
    long = by_policy(bars, candidates, config).loc["immediate"]
    candidates["side"] = "SHORT"
    short = by_policy(bars, candidates, config).loc["immediate"]
    assert long.gross_hold10 == 100
    assert long.gross_hold10_atr == .5
    assert long.net_hold10_atr == pytest.approx((1 - .019) / 2)
    assert short.gross_hold10 == -100
    assert short.net_hold10 == pytest.approx(-101.9)


def test_original_unexecutable_entries_retained_with_zero_opportunity():
    bars, candidates, config = setup()
    candidates["nominal_close_time"] = 5600
    candidates["eligible"] = False
    out = evaluate_timing(bars, candidates, config)
    assert len(out) == 6
    assert set(out.status) == {"unexecutable"}
    assert set(out.status_reason) == {"original_entry_delay_exceeded"}
    assert not out.common_pool.any()
    assert out.opp_net_hold10.eq(0).all()
    candidates["entry_index"] = len(bars)
    candidates["entry_time"] = -1
    out = evaluate_timing(bars, candidates, config)
    assert set(out.status_reason) == {"original_entry_unavailable"}


def test_filled_endpoint_censoring_does_not_change_status():
    bars, candidates, config = setup(count=35)
    out = by_policy(bars, candidates, config)
    assert out.loc["immediate", "status"] == "filled"
    assert out.loc["immediate", "endpoint_complete_hold10"]
    assert not out.loc["immediate", "endpoint_complete_deadline50"]
    assert np.isnan(out.loc["immediate", "opp_net_deadline50"])
    assert out.loc["pullback", "status"] == "expired"
    assert out.loc["pullback", "opp_net_deadline50"] == 0


def test_controls_preserve_replicate_without_overwriting_control_origin_id():
    bars, candidates, config = setup()
    candidates["replicate"] = 7
    candidates["origin_candidate_id"] = "matched_strategy_origin"
    out = evaluate_timing(bars, candidates, config)
    assert out.replicate.eq(7).all()
    assert out.origin_candidate_id.eq("origin").all()
    assert out.matched_origin_candidate_id.eq("matched_strategy_origin").all()
    assert out.attrs["timing_metadata"]["roundtrip_cost_pips"] == pytest.approx(1.9)


def test_empty_candidates_and_unverified_availability():
    bars, candidates, config = setup()
    out = evaluate_timing(bars, candidates.iloc[:0], config)
    assert out.empty and "opp_net_hold10" in out
    bars.loc[20, "available_time"] = bars.loc[20, "time"]
    with pytest.raises(ValueError, match="availability cannot precede"):
        evaluate_timing(bars, candidates, config)
