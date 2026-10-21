import numpy as np
import pandas as pd
import pytest

from tools.entry_research.diagnostics.exits import barrier_scenarios


def setup(side="LONG"):
    times = np.arange(52, dtype=np.int64) * 300
    bars = pd.DataFrame({"time": times, "open": 100., "high": 100., "low": 100., "close": 100., "spread": 15})
    candidates = pd.DataFrame({"candidate_id": ["origin"], "method": ["fixture"], "side": [side],
        "signal_index": [0], "entry_index": [1], "signal_time": [300], "nominal_close_time": [300],
        "entry_time": [300], "atr14": [2.], "eligible": [True], "week": ["2024-01-01"], "year": [2024]})
    config = {"timeframe_seconds": 300, "pip_size": .01, "max_entry_delay_seconds": 300,
              "end_exclusive": 15600, "barrier_levels": [.5],
              "cost": {"mode": "assumed", "spread_pips": 1.5,
                       "commission_pips_roundtrip": 0., "slippage_pips_per_side": .2}}
    return bars, candidates, config


@pytest.mark.parametrize("side,high,low,outcome,value", [
    ("LONG", 101., 100., "tp_first", 98.1), ("LONG", 100., 99., "sl_first", -101.9),
    ("SHORT", 101., 100., "sl_first", -101.9), ("SHORT", 100., 99., "tp_first", 98.1),
])
def test_ideal_first_barrier_side_and_cost(side, high, low, outcome, value):
    bars, candidates, config = setup(side)
    bars.loc[1, ["high", "low"]] = [high, low]
    row = barrier_scenarios(bars, candidates, config).iloc[0]
    assert row.outcome == outcome
    assert row.first_hit_bar == 1
    assert row.net_lower_pips == pytest.approx(value)
    assert row.net_upper_pips == pytest.approx(value)


def test_ambiguous_bounds_only_touch_order():
    bars, candidates, config = setup()
    bars.loc[1, ["high", "low"]] = [101, 99]
    row = barrier_scenarios(bars, candidates, config).iloc[0]
    assert row.outcome == "ambiguous"
    assert row.net_lower_pips == pytest.approx(-101.9)
    assert row.net_upper_pips == pytest.approx(98.1)
    assert row.scenario == "ideal_barrier_no_gap_slippage_guarantee"
    assert row.bounds_basis == "same_bar_order_only_not_execution_or_gap_bounds"


def test_neither_uses_h50_close_and_not_h51():
    bars, candidates, config = setup()
    bars.loc[50, ["high", "close"]] = [100.2, 100.2]
    bars.loc[51, ["high", "close"]] = [150., 150.]
    row = barrier_scenarios(bars, candidates, config).iloc[0]
    assert row.outcome == "neither"
    assert row.net_lower_pips == pytest.approx(18.1)
    assert row.net_upper_pips == pytest.approx(18.1)


def test_gap_order_known_but_overshoot_is_explicitly_not_fill_profit():
    bars, candidates, config = setup()
    bars.loc[2, ["open", "high", "low", "close"]] = [102, 102, 98, 100]
    row = barrier_scenarios(bars, candidates, config).iloc[0]
    assert row.outcome == "tp_first"
    assert row.first_hit_bar == 2
    assert row.net_lower_pips == pytest.approx(98.1)
    assert row.gap_overshoot_ignored


def test_fixed_diagonal_levels_cohort_and_replicate_preserved():
    bars, candidates, config = setup()
    config["barrier_levels"] = [.5, 1, 1.5]
    candidates["replicate"] = 4
    other = candidates.copy()
    other["candidate_id"] = "excluded"
    other["eligible"] = False
    out = barrier_scenarios(bars, pd.concat([candidates, other], ignore_index=True), config)
    assert len(out) == 3
    assert set(out.level) == {.5, 1, 1.5}
    assert out.candidate_id.eq("origin").all()
    assert out.replicate.eq(4).all()
    assert out.week.eq("2024-01-01").all()
    assert out.attrs["barrier_metadata"]["not_executable_profit_bounds"]


def test_missing_future_remains_censored_without_imputed_pnl():
    bars, candidates, config = setup()
    out = barrier_scenarios(bars.iloc[:20], candidates, config)
    assert out.outcome.eq("censored").all()
    assert out.net_lower_pips.isna().all()
    assert out.net_upper_pips.isna().all()


def test_empty_original_eligible_pool_has_stable_output():
    bars, candidates, config = setup()
    candidates["eligible"] = False
    out = barrier_scenarios(bars, candidates, config)
    assert out.empty
    assert "net_lower_pips" in out and "scenario" in out
