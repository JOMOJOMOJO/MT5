import numpy as np
import pandas as pd
import pytest

from tools.entry_research.evaluation import evaluate, resolve_tick_first_touch


def fixture_frames():
    bars = pd.DataFrame({
        "time": [0, 300, 600, 900], "open": [99., 100., 101., 102.],
        "high": [100., 103., 104., 103.], "low": [98., 99., 100., 98.],
        "close": [99.5, 102., 103., 100.], "spread": [3., 4., 8., 6.],
    })
    candidates = pd.DataFrame({
        "candidate_id": ["L", "S"], "method": ["fixture", "fixture"],
        "side": ["LONG", "SHORT"], "signal_index": [0, 0], "entry_index": [1, 1],
        "signal_time": [300, 300], "nominal_close_time": [300, 300],
        "entry_time": [300, 300], "atr14": [2., 2.],
    })
    config = {"horizons": [1, 2], "levels": [.5, 1.], "pip_size": .01,
              "point": .001, "timeframe_seconds": 300, "end_exclusive": 1500,
              "cost": {"mode": "assumed", "spread_pips": 1.5,
                       "commission_pips_roundtrip": .3, "slippage_pips_per_side": .2}}
    return bars, candidates, config


def test_horizon_entry_close_cost_and_direction():
    bars, candidates, config = fixture_frames()
    outcomes, _, _ = evaluate(bars, candidates, config)
    long = outcomes.query("candidate_id == 'L' and horizon == 1").iloc[0]
    short = outcomes.query("candidate_id == 'S' and horizon == 1").iloc[0]
    assert long.gross_pips == 200
    assert long.net_pips == pytest.approx(197.8)
    assert long.gross_atr == 1
    assert long.net_atr == pytest.approx(.989)
    assert long.exit_time == 600
    assert short.gross_pips == -200
    assert short.net_pips == pytest.approx(-202.2)


def test_mfe_mae_same_horizon_and_frozen_atr():
    bars, candidates, config = fixture_frames()
    outcomes, _, _ = evaluate(bars, candidates, config)
    long1 = outcomes.query("candidate_id == 'L' and horizon == 1").iloc[0]
    long2 = outcomes.query("candidate_id == 'L' and horizon == 2").iloc[0]
    short2 = outcomes.query("candidate_id == 'S' and horizon == 2").iloc[0]
    assert (long1.mfe_pips, long1.mae_pips) == (300, 100)
    assert (long2.mfe_atr, long2.mae_atr) == (2, .5)
    assert (short2.mfe_atr, short2.mae_atr) == (.5, 2)


def test_same_bar_ambiguous_and_touch_interval():
    bars, candidates, config = fixture_frames()
    _, touches, barriers = evaluate(bars, candidates, config)
    row = barriers.query("candidate_id == 'L' and horizon == 1 and tp_atr == .5 and sl_atr == .5").iloc[0]
    assert row.outcome == "ambiguous"
    assert row.first_hit_bar == 1
    assert (row.hit_time_lower, row.hit_time_upper) == (300, 600)
    hit = touches.query("candidate_id == 'L' and horizon == 1 and move == 'favorable' and level == 1").iloc[0]
    assert hit.reached
    assert (hit.hit_time_lower, hit.hit_time_upper) == (300, 600)


@pytest.mark.parametrize("side,opening,expected", [("LONG", 103., "tp_first"),
                                                   ("LONG", 97., "sl_first"),
                                                   ("SHORT", 103., "sl_first"),
                                                   ("SHORT", 97., "tp_first")])
def test_price_gap_open_resolves_intrabar_double_touch(side, opening, expected):
    bars, candidates, config = fixture_frames()
    bars.loc[1, ["open", "high", "low", "close"]] = [100, 100.5, 99.5, 100]
    bars.loc[2, ["open", "high", "low", "close"]] = [opening, 104, 96, 100]
    candidates = candidates[candidates.side == side]
    _, _, barriers = evaluate(bars, candidates, config)
    row = barriers.query("horizon == 2 and tp_atr == 1 and sl_atr == 1").iloc[0]
    assert row.outcome == expected
    assert (row.hit_time_lower, row.hit_time_upper) == (600, 600)


def test_neither_and_first_side_at_different_bars():
    bars, candidates, config = fixture_frames()
    bars.loc[1, ["high", "low", "close"]] = [100.8, 99.8, 100.5]
    bars.loc[2, ["open", "high", "low", "close"]] = [100.5, 103, 99.8, 102]
    _, touches, barriers = evaluate(bars, candidates, config)
    row1 = barriers.query("candidate_id == 'L' and horizon == 1 and tp_atr == 1 and sl_atr == 1").iloc[0]
    row2 = barriers.query("candidate_id == 'L' and horizon == 2 and tp_atr == 1 and sl_atr == 1").iloc[0]
    assert row1.outcome == "neither"
    assert np.isnan(row1.first_hit_bar)
    assert row2.outcome == "tp_first"
    assert row2.first_hit_bar == 2
    assert not touches.query("candidate_id == 'L' and horizon == 1").reached.any()


@pytest.mark.parametrize("kind,reason", [("clock_gap", "time_gap"),
                                       ("end", "development_boundary"),
                                       ("missing", "insufficient_future_bars"),
                                       ("ohlc", "invalid_ohlc")])
def test_incomplete_windows_censored_without_fake_losses(kind, reason):
    bars, candidates, config = fixture_frames()
    if kind == "clock_gap":
        bars.loc[2:, "time"] += 300
    elif kind == "end":
        config["end_exclusive"] = 600
    elif kind == "missing":
        bars = bars.iloc[:2]
    else:
        bars.loc[2, "high"] = np.nan
    outcomes, touches, barriers = evaluate(bars, candidates, config)
    censored = outcomes[outcomes.horizon == 2]
    assert not censored.complete.any()
    assert set(censored.censor_reason) == {reason}
    assert censored.gross_pips.isna().all()
    assert touches.query("horizon == 2").reached.isna().all()
    assert set(barriers.query("horizon == 2").outcome) == {"censored"}
    assert outcomes.query("horizon == 1").complete.all()


def test_entry_delay_is_recorded_and_signal_availability_is_enforced():
    bars, candidates, config = fixture_frames()
    candidates["nominal_close_time"] = 0
    outcomes, _, _ = evaluate(bars, candidates, config)
    assert outcomes.complete.all()
    assert (outcomes.entry_delay_seconds == 300).all()
    candidates["nominal_close_time"] = 300
    candidates["signal_time"] = 301
    outcomes, _, _ = evaluate(bars, candidates, config)
    assert set(outcomes.censor_reason) == {"entry_before_signal_available"}
    candidates["signal_time"] = 300
    candidates["entry_index"] = 0
    outcomes, _, _ = evaluate(bars, candidates, config)
    assert set(outcomes.censor_reason) == {"entry_not_after_signal_bar"}


def test_bar_spread_is_side_correct_proxy_with_explicit_fallback():
    bars, candidates, config = fixture_frames()
    config["cost"]["mode"] = "bar_proxy"
    outcomes, _, _ = evaluate(bars, candidates, config)
    rows = outcomes[outcomes.horizon == 2].set_index("side")
    assert rows.loc["LONG", "spread_cost_pips"] == pytest.approx(.4)
    assert rows.loc["SHORT", "spread_cost_pips"] == pytest.approx(.8)
    assert "proxy" in rows.loc["SHORT", "cost_source"]
    bars["spread"] = 0
    outcomes, _, _ = evaluate(bars, candidates, config)
    assert (outcomes.spread_cost_pips == 1.5).all()
    assert outcomes.cost_source.str.contains("assumed_fallback").all()


def test_entry_delay_limit_and_missing_entry_priority():
    bars, candidates, config = fixture_frames()
    config["max_entry_delay_seconds"] = 300
    candidates["nominal_close_time"] = 0
    outcomes, _, _ = evaluate(bars, candidates, config)
    assert outcomes.complete.all()
    assert (outcomes.entry_delay_seconds == 300).all()
    candidates["entry_index"] = 2
    candidates["entry_time"] = 600
    outcomes, touches, barriers = evaluate(bars, candidates, config)
    assert set(outcomes.censor_reason) == {"entry_delay_exceeded"}
    assert outcomes.net_pips.isna().all()
    assert touches.reached.isna().all()
    assert set(barriers.outcome) == {"censored"}
    candidates["entry_index"] = -1
    candidates["entry_time"] = -1
    outcomes, _, _ = evaluate(bars, candidates, config)
    assert set(outcomes.censor_reason) == {"entry_unavailable"}


def test_future_mutation_cannot_change_shorter_horizon():
    bars, candidates, config = fixture_frames()
    original = evaluate(bars, candidates, config)
    bars.loc[2:, ["open", "high", "low", "close"]] += 1000
    mutated = evaluate(bars, candidates, config)
    for left, right in zip(original, mutated):
        pd.testing.assert_frame_equal(left[left.horizon == 1].reset_index(drop=True),
                                      right[right.horizon == 1].reset_index(drop=True))


def test_empty_candidates_preserve_schema():
    bars, candidates, config = fixture_frames()
    outcomes, touches, barriers = evaluate(bars, candidates.iloc[:0], config)
    assert outcomes.empty and touches.empty and barriers.empty
    assert "net_pips" in outcomes and "reached" in touches and "outcome" in barriers


def test_optional_path_emission_does_not_change_outcomes():
    bars, candidates, config = fixture_frames()
    original, _, _ = evaluate(bars, candidates, config)
    config["emit_paths"] = False
    outcomes, touches, barriers = evaluate(bars, candidates, config)
    pd.testing.assert_frame_equal(original, outcomes)
    assert touches.empty and barriers.empty


def test_tick_resolution_requires_verified_coverage_and_order():
    ticks = pd.DataFrame({"time": [301, 302, 303], "bid": [100, 103, 97]})
    args = (ticks, 100., "LONG", 2., 1., 1.)
    assert resolve_tick_first_touch(*args)["outcome"] == "unknown"
    assert resolve_tick_first_touch(*args, coverage_complete=True)["outcome"] == "tp_first"
    ticks["time"] = [301, 303, 302]
    assert resolve_tick_first_touch(*args, coverage_complete=True)["outcome"] == "unknown"
    ticks["time"] = [301, 302, 302]
    assert resolve_tick_first_touch(*args, coverage_complete=True)["outcome"] == "ambiguous"


def test_tick_short_reverse_and_no_hit():
    ticks = pd.DataFrame({"time": [1, 2], "bid": [100, 103]})
    assert resolve_tick_first_touch(ticks, 100, "SHORT", 2, 1, 1, coverage_complete=True)["outcome"] == "sl_first"
    assert resolve_tick_first_touch(ticks, 100, "LONG", 2, 2, 2, coverage_complete=True)["outcome"] == "neither"
