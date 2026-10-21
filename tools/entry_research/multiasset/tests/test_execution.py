"""Hand-computed execution, sizing, conversion, censor and ambiguity fixtures."""
import numpy as np
import pandas as pd
import pytest

from tools.entry_research.multiasset.execution import floor_volume, quote_to_usd, simulate


def fixture(symbol="EURUSD", side="LONG", count=6):
    jpy = symbol.startswith("USDJPY")
    price, atr = (150., .1) if jpy else (1.1, .001)
    times = 1704186000 + np.arange(count) * 300
    bars = pd.DataFrame({"time": times, "open": price, "high": price + atr*.4,
                         "low": price - atr*.4, "close": price, "spread": 15 if jpy else 20})
    candidates = pd.DataFrame({"candidate_id": ["a"], "method": ["fixture"], "side": [side],
        "symbol": [symbol], "signal_index": [0], "signal_time": [times[1]],
        "entry_index": [1], "entry_time": [times[1]], "atr14": [atr]})
    spec = {"symbol": symbol, "point": .001 if jpy else .00001, "pip_size": .01 if jpy else .0001,
            "contract_size": 100000, "volume_min": .01, "volume_step": .01, "volume_max": 100,
            "currency_profit": symbol[3:6], "historical_spec_verified": False}
    config = {"max_hold_bars": 2, "initial_equity": 10000, "risk_fraction": .001,
              "timeframe_seconds": 300, "tp_atr": 1., "sl_atr": 1.,
              "slippage_pips_per_side": .2, "commission_per_lot_roundtrip_usd": 0}
    return bars, candidates, spec, config


def test_minimum_lot_never_overrides_target_risk():
    assert floor_volume(10, 102, .01, .01, 100) == .09
    assert floor_volume(10, 102, .1, .01, 100) == 0
    bars, events, spec, config = fixture()
    spec["volume_min"] = .1
    result = simulate(bars, events, spec, config)
    assert result["events"].status.eq("skipped_min_lot_risk").all()
    assert result["summary"].n_closed.eq(0).all()
    assert result["summary"].ending_realized_balance_usd.eq(10000).all()


def test_late_entry_expiry_is_not_a_future_completeness_filter():
    bars, events, spec, config = fixture()
    events['nominal_close_time'] = events.signal_time-301
    result = simulate(bars, events, spec, config)
    assert result['events'].status.eq('skipped_entry_expired').all()
    assert result['summary'].n_opened.eq(0).all()
    events['nominal_close_time'] = events.signal_time-300
    result = simulate(bars, events, spec, config)
    assert result['summary'].n_closed.eq(1).all()
    assert result['summary'].win_rate.eq(0).all()


def test_late_observation_cannot_extend_expiry():
    bars, events, spec, config = fixture()
    events['nominal_close_time'] = events.signal_time
    events['signal_time'] += 301
    events['entry_index'] = 3
    events['entry_time'] = bars.time.iloc[3]
    result = simulate(bars, events, spec, config)
    assert result['events'].status.eq('skipped_entry_expired').all()


@pytest.mark.parametrize("side", ["LONG", "SHORT"])
def test_same_bar_ambiguity_retains_both_account_scenarios(side):
    bars, events, spec, config = fixture(side=side)
    bars.loc[1, ["high", "low"]] = [1.102, 1.098]
    result = simulate(bars, events, spec, config)
    trades = result["trades"].set_index("scenario")
    assert trades.ambiguous.all()
    assert trades.volume.eq(.09).all()
    assert trades.loc["stop_first_lower", "net_pnl_usd"] == pytest.approx(-9.18)
    assert trades.loc["target_first_upper", "net_pnl_usd"] == pytest.approx(8.82)
    assert trades.loc["stop_first_lower", "result_r"] == pytest.approx(-1)
    assert trades.loc["target_first_upper", "result_r"] == pytest.approx(8.82/9.18)
    assert not result["summary"].account_pnl_promotion_eligible.any()
    assert not result["summary"].scenario_is_global_bound.any()


def test_gap_stop_fills_at_open_and_can_exceed_planned_loss():
    bars, events, spec, config = fixture()
    bars.loc[2, ["open", "high", "low", "close"]] = [1.098, 1.0985, 1.0975, 1.098]
    trades = simulate(bars, events, spec, config)["trades"]
    assert trades.exit_reason.eq("stop_gap_open").all()
    assert trades.exit_fill.to_numpy() == pytest.approx(np.full(2, 1.09798))
    assert trades.net_pnl_usd.to_numpy() == pytest.approx(np.full(2, -20.16))
    assert trades.loss_exceeds_planned_risk.all()
    assert trades.exit_time.eq(bars.time.iloc[2]).all()


def test_overlap_is_rejected_until_existing_trade_is_closed():
    bars, events, spec, config = fixture()
    events = pd.concat([events, events.assign(candidate_id="b", signal_index=1, signal_time=bars.time.iloc[2],
                entry_index=2, entry_time=bars.time.iloc[2]),
        events.assign(candidate_id="c", signal_index=2, signal_time=bars.time.iloc[3], entry_index=3, entry_time=bars.time.iloc[3])], ignore_index=True)
    result = simulate(bars, events, spec, config)
    ledger = result["events"]
    assert ledger.loc[ledger.candidate_id.eq("b"), "status"].eq("skipped_overlap").all()
    assert ledger.loc[ledger.candidate_id.isin(["a", "c"]), "status"].eq("executed").all()
    assert result["summary"].n_closed.eq(2).all()
    assert result["summary"].n_skipped_overlap.eq(1).all()


def test_censored_position_blocks_future_accounts_without_inventing_exit():
    bars, events, spec, config = fixture()
    bars.loc[2:, "time"] += 300
    later = events.assign(candidate_id="b", signal_index=2, signal_time=bars.time.iloc[3], entry_index=3, entry_time=bars.time.iloc[3])
    events = pd.concat([events, later], ignore_index=True)
    result = simulate(bars, events, spec, config)
    assert result["trades"].status.eq("censored_time_gap").all()
    assert result["trades"].net_pnl_usd.isna().all()
    assert result["events"].loc[result["events"].candidate_id.eq("b"), "status"].eq("skipped_account_censored").all()
    assert not result["summary"].account_path_complete.any()
    assert result["summary"].return_pct.isna().all()


def test_future_gap_does_not_remove_an_already_exited_trade():
    bars, events, spec, config = fixture()
    bars.loc[1, "high"] = 1.102
    bars.loc[2:, "time"] += 300
    result = simulate(bars, events, spec, config)
    assert result["trades"].status.eq("closed").all()
    assert result["trades"].exit_reason.eq("target").all()


def test_inverse_quote_conversion_uses_historical_midpoint_not_current_tick_value():
    bars, events, spec, config = fixture("USDJPY")
    bars.loc[1, "high"] = 150.2
    first = simulate(bars, events, spec, config)
    changed = simulate(bars, events, {**spec, "trade_tick_value": 999999}, config)
    pd.testing.assert_frame_equal(first["trades"], changed["trades"])
    trade = first["trades"].iloc[0]
    assert trade.volume == .14
    assert trade.exit_conversion_quote_to_usd == pytest.approx(1 / (trade.target_price + .015/2))
    expected = (trade.exit_fill - trade.entry_fill) * 100000 * .14 / (trade.target_price + .015/2)
    assert trade.net_pnl_usd == pytest.approx(expected)
    assert quote_to_usd("EURUSD", 1.1) == 1
    assert quote_to_usd("USDCHF", .9) == pytest.approx(1/.9)
    assert quote_to_usd("USDCAD", 1.3) == pytest.approx(1/1.3)


def test_nonpositive_spread_is_labelled_fallback_and_overnight_swap_unknown():
    bars, events, spec, config = fixture()
    start = int(pd.Timestamp("2024-01-02 23:50:00").timestamp())
    bars.time = start + np.arange(len(bars))*300
    bars.spread = 0
    events["signal_time"] = events["entry_time"] = bars.time.iloc[1]
    result = simulate(bars, events, spec, config)
    trades = result["trades"]
    assert trades.entry_spread_source.eq("assumed_spread_fallback").all()
    assert trades.entry_spread_pips.eq(2).all()
    assert trades.overnight_source_day_crossing.all() and trades.swap_unknown.all()
    assert not trades.swap_cost_included.any()
    assert result["summary"].n_overnight.eq(1).all()


def test_drawdown_includes_adverse_open_position_marks():
    bars, events, spec, config = fixture()
    bars.loc[1, "low"] = 1.0993
    bars.loc[2, "close"] = 1.1003
    result = simulate(bars, events, spec, config)
    summary = result["summary"]
    assert (summary.max_drawdown_adverse_envelope_pct > summary.max_drawdown_close_pct).all()
    assert summary.max_drawdown_adverse_envelope_pct.gt(0).all()
    assert result["equity"].intrabar_order_unknown.any()


def test_time_exit_commission_and_net_profit_reconcile():
    bars, events, spec, config = fixture()
    config["commission_per_lot_roundtrip_usd"] = 7
    result = simulate(bars, events, spec, config)
    trades = result["trades"]
    assert trades.exit_reason.eq("time_exit").all()
    assert trades.net_pnl_usd.to_numpy() == pytest.approx(np.full(2, -.00024*100000*.09 - 7*.09))
    assert result["summary"].net_pnl_usd.to_numpy() == pytest.approx(trades.net_pnl_usd.to_numpy())


def test_rejects_mixed_accounts_and_holdout_prices():
    bars, events, spec, config = fixture()
    with pytest.raises(ValueError, match="One method/direction"):
        simulate(bars, pd.concat([events, events.assign(candidate_id="s", side="SHORT")]), spec, config)
    bars.loc[len(bars)-1, "time"] = 1767225600
    with pytest.raises(ValueError, match="holdout"):
        simulate(bars, events, spec, config)
