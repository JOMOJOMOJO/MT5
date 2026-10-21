"""Independent executable-rule account scenarios; never a claim of MT5 fills.

One method/symbol/direction is an independent USD account. Bid OHLC plus a
bar-spread proxy constructs executable quotes. SL/TP are fill-relative market
exit triggers. Same-bar order has two explicit conventions, and intrabar equity
drawdown is an envelope because OHLC does not reveal its chronological path.
"""
from __future__ import annotations

import math

import numpy as np
import pandas as pd
from .calendar import annotate_bars

HOLDOUT_START = 1767225600  # 2026-01-01; no holdout prices in this simulator.
SCENARIOS = ("stop_first_lower", "target_first_upper")
SUPPORTED = {"EURUSD", "GBPUSD", "AUDUSD", "USDJPY", "USDCHF", "USDCAD"}


def quote_to_usd(symbol: str, midpoint: float) -> float:
    """Historical conversion from the same pair's contemporaneous midpoint."""
    pair = symbol[:6].upper()
    if pair not in SUPPORTED or not np.isfinite(midpoint) or midpoint <= 0:
        raise ValueError("Supported USD pair and positive historical midpoint required")
    return 1.0 if pair.endswith("USD") else 1.0 / midpoint


def floor_volume(risk_budget: float, risk_per_lot: float, minimum: float, step: float, maximum: float) -> float:
    """Never force the broker minimum when it exceeds the risk budget."""
    if not all(np.isfinite(x) and x > 0 for x in (risk_budget, risk_per_lot, minimum, step, maximum)):
        return 0.0
    raw = min(risk_budget / risk_per_lot, maximum)
    volume = math.floor(raw / step + 1e-10) * step
    if volume < minimum - 1e-10 or volume * risk_per_lot > risk_budget + 1e-8:
        return 0.0
    return float(round(volume, 10))


def _round_price(price: float, tick: float, up: bool) -> float:
    units = math.ceil(price / tick - 1e-9) if up else math.floor(price / tick + 1e-9)
    return float(units * tick)


def _positive(value, name):
    value = float(value)
    if not np.isfinite(value) or value <= 0:
        raise ValueError(f"{name} must be finite and positive")
    return value


def simulate(bars: pd.DataFrame, candidates: pd.DataFrame, spec: dict, config: dict) -> dict:
    """Return trades/events/equity/summary DataFrames for two order scenarios.

    Required spec: symbol, point, pip_size, contract_size, volume_min,
    volume_step, volume_max. Optional trade_tick_size, trade_stops_level,
    currency_profit, account_currency, historical_spec_verified are recorded.
    Config: timeframe_seconds=300, max_hold_bars=10, sl_atr=tp_atr=1,
    initial_equity=10000, risk_fraction=.001, assumed_spread_pips=1.5 for
    USDJPY else2, slippage_pips_per_side=.2, commission_per_lot_roundtrip_usd=0.

    No pyramiding or portfolio combination. A censored open position blocks
    subsequent candidates: neither its exit nor a fictitious flat state is
    invented. Overnight swap and margin remain unverified, blocking promotion.
    """
    symbol = str(spec["symbol"])
    pair = symbol[:6].upper()
    if pair not in SUPPORTED or spec.get("account_currency", "USD") != "USD":
        raise ValueError("Only the six declared USD pairs and a USD account are supported")
    if spec.get("currency_profit", pair[3:]) != pair[3:]:
        raise ValueError("currency_profit must be the pair's quote currency")
    point, pip, contract = (_positive(spec[k], k) for k in ("point", "pip_size", "contract_size"))
    lot_min, lot_step, lot_max = (_positive(spec[k], k) for k in ("volume_min", "volume_step", "volume_max"))
    if lot_max < lot_min or abs(lot_min / lot_step - round(lot_min / lot_step)) > 1e-7:
        raise ValueError("Unsupported minimum/step geometry or maximum below minimum")
    tick = _positive(spec.get("trade_tick_size", spec.get("tick_size", point)), "trade_tick_size")
    stop_level = float(spec.get("trade_stops_level", 0)) * point
    initial = _positive(config.get("initial_equity", 10000), "initial_equity")
    risk_fraction = _positive(config.get("risk_fraction", .001), "risk_fraction")
    if risk_fraction >= 1:
        raise ValueError("risk_fraction must be below 1")
    sl_atr, tp_atr = (_positive(config.get(k, 1), k) for k in ("sl_atr", "tp_atr"))
    hold, step = int(config.get("max_hold_bars", 10)), int(config.get("timeframe_seconds", 300))
    if hold < 1 or step < 1 or hold != config.get("max_hold_bars", 10) or step != config.get("timeframe_seconds", 300):
        raise ValueError("Holding period and timeframe must be positive integer counts")
    spread_setting = config.get("assumed_spread_pips", 1.5 if pair == "USDJPY" else 2.0)
    spread_assumed = float(spread_setting[pair] if isinstance(spread_setting, dict) else spread_setting)
    slip = float(config.get("slippage_pips_per_side", .2)) * pip
    commission = float(config.get("commission_per_lot_roundtrip_usd", 0))
    if any(not np.isfinite(x) or x < 0 for x in (spread_assumed, slip, commission, stop_level)):
        raise ValueError("Cost and broker stop-level assumptions must be nonnegative")
    required_bars = {"time", "open", "high", "low", "close"}
    required_events = {"candidate_id", "method", "side", "entry_index", "entry_time", "signal_time", "atr14"}
    if required_bars - set(bars) or required_events - set(candidates):
        raise ValueError("Missing bar or candidate contract columns")
    # Rebuild trusted annotations from timestamps and explicit policy. A caller
    # cannot authorize an unexplained gap by supplying a forged status column.
    b = annotate_bars(bars, step, config.get('calendar_policy'))
    if b.time.isna().any() or b.time.duplicated().any() or not b.time.is_monotonic_increasing:
        raise ValueError("Bar times must be non-null, unique and increasing")
    if (b.time >= HOLDOUT_START).any():
        raise ValueError("2026 holdout prices are forbidden")
    if candidates.candidate_id.isna().any() or candidates.candidate_id.duplicated().any():
        raise ValueError("Candidate IDs must be present and unique")
    if not candidates.side.isin(["LONG", "SHORT"]).all() or candidates[["method", "side"]].drop_duplicates().shape[0] > 1:
        raise ValueError("One method/direction independent account per call is required")
    if "symbol" in candidates and not candidates.symbol.eq(symbol).all():
        raise ValueError("Candidate symbol does not match the account spec")
    events = candidates.sort_values(["entry_time", "candidate_id"]).reset_index(drop=True)
    method = str(events.method.iloc[0]) if len(events) else str(config.get("method", "empty"))
    side = str(events.side.iloc[0]) if len(events) else str(config.get("side", "LONG"))
    sign = 1 if side == "LONG" else -1
    end = min(int(config.get("end_exclusive", HOLDOUT_START)), HOLDOUT_START)
    times = b.time.to_numpy(dtype=np.int64)
    gap_status = b.gap_before_status.to_numpy()
    gap_seconds = b.gap_before_seconds.to_numpy(dtype=np.int64)
    gap_evidence = b.gap_evidence.to_numpy()
    prices = {key: pd.to_numeric(b[key], errors="coerce").to_numpy(dtype=float) for key in ("open", "high", "low", "close")}
    spread_points = pd.to_numeric(b["spread"], errors="coerce").to_numpy(dtype=float) if "spread" in b else np.full(len(b), np.nan)
    measured = np.isfinite(spread_points) & (spread_points > 0)
    spreads = np.where(measured, spread_points * point, spread_assumed * pip)
    spread_sources = np.where(measured, "positive_bar_spread_proxy", "assumed_spread_fallback")
    valid_price = np.logical_and.reduce([np.isfinite(v) & (v > 0) for v in prices.values()])
    valid_price &= ((prices["high"] >= np.maximum(prices["open"], prices["close"])) &
                    (prices["low"] <= np.minimum(prices["open"], prices["close"])) & (prices["high"] >= prices["low"]))
    trade_rows, event_rows, equity_rows, summaries = [], [], [], []

    for scenario in SCENARIOS:
        balance, peak_close, peak_envelope = initial, initial, initial
        allow_index, blocked, blocking_id = 0, False, ""
        scenario_trades, scenario_equity = [], []

        def mark(time, idx, candidate_id, close_equity, adverse_equity, favorable_equity, phase):
            nonlocal peak_close, peak_envelope
            peak_close = max(peak_close, close_equity)
            peak_envelope = max(peak_envelope, favorable_equity, close_equity)
            row = {"scenario": scenario, "symbol": symbol, "method": method, "side": side,
                   "time": int(time), "bar_index": idx, "candidate_id": candidate_id, "phase": phase,
                   "balance_usd": balance, "equity_close_usd": close_equity,
                   "equity_adverse_usd": adverse_equity, "equity_favorable_usd": favorable_equity,
                   "drawdown_close_usd": peak_close - close_equity,
                   "drawdown_close_pct": 100 * (peak_close - close_equity) / peak_close,
                   "drawdown_adverse_usd": peak_envelope - adverse_equity,
                   "drawdown_adverse_pct": 100 * (peak_envelope - adverse_equity) / peak_envelope,
                   "intrabar_order_unknown": phase == "bar_envelope"}
            equity_rows.append(row)
            scenario_equity.append(row)

        mark(int(times[0]) if len(times) else 0, -1, "", initial, initial, initial, "initial")
        for candidate in events.to_dict("records"):
            cid = str(candidate["candidate_id"])
            event = {"scenario": scenario, "symbol": symbol, "method": method, "side": side,
                     "candidate_id": cid, "entry_time": candidate["entry_time"], "entry_index": candidate["entry_index"],
                     "balance_before_usd": balance, "status": "", "blocking_candidate_id": ""}
            if blocked:
                event.update(status="skipped_account_censored", blocking_candidate_id=blocking_id)
                event_rows.append(event)
                continue
            raw_index = candidate["entry_index"]
            if not np.isfinite(raw_index) or int(raw_index) != raw_index or raw_index < 0 or raw_index >= len(b):
                event["status"] = "skipped_missing_entry"
                event_rows.append(event)
                continue
            entry = int(raw_index)
            if entry < allow_index:
                event.update(status="skipped_overlap", blocking_candidate_id=blocking_id)
                event_rows.append(event)
                continue
            if (candidate["entry_time"] != times[entry] or candidate["signal_time"] > times[entry]
                    or times[entry] >= end or not valid_price[entry]):
                event["status"] = "skipped_invalid_entry"
                event_rows.append(event)
                continue
            nominal_close = candidate.get("nominal_close_time", candidate["signal_time"])
            if times[entry] - nominal_close > config.get("max_entry_delay_seconds", step):
                event["status"] = "skipped_entry_expired"
                event_rows.append(event)
                continue
            if "signal_index" in candidate:
                signal_idx = int(candidate["signal_index"])
                if signal_idx < 0 or signal_idx >= entry or candidate["signal_time"] < times[signal_idx] + step:
                    event["status"] = "skipped_unconfirmed_signal"
                    event_rows.append(event)
                    continue
            atr = float(candidate["atr14"])
            if not np.isfinite(atr) or atr <= 0 or balance <= 0:
                event["status"] = "skipped_invalid_atr_or_equity"
                event_rows.append(event)
                continue
            entry_quote = prices["open"][entry] + (spreads[entry] if sign > 0 else 0)
            entry_fill = _round_price(entry_quote + sign * slip, tick, up=sign > 0)
            stop = _round_price(entry_fill - sign * sl_atr * atr, tick, up=sign < 0)
            target = _round_price(entry_fill + sign * tp_atr * atr, tick, up=sign > 0)
            entry_exit_quote = prices["open"][entry] + (spreads[entry] if sign < 0 else 0)
            if stop <= 0 or target <= 0 or sign * (entry_exit_quote - stop) <= stop_level or sign * (target - entry_exit_quote) <= stop_level:
                event["status"] = "skipped_stop_geometry"
                event_rows.append(event)
                continue
            entry_mid = prices["open"][entry] + spreads[entry] / 2
            stop_mid = stop + sign * spreads[entry] / 2
            stop_fill = _round_price(stop - sign * slip, tick, up=sign < 0)
            risk_conversion = max(quote_to_usd(symbol, entry_mid), quote_to_usd(symbol, stop_mid))
            risk_per_lot = sign * (entry_fill - stop_fill) * contract * risk_conversion + commission
            budget = balance * risk_fraction
            volume = floor_volume(budget, risk_per_lot, lot_min, lot_step, lot_max)
            if volume == 0:
                event.update(status="skipped_min_lot_risk", risk_budget_usd=budget, min_lot_risk_usd=lot_min*risk_per_lot)
                event_rows.append(event)
                continue
            before = balance
            trade = {"scenario": scenario, "symbol": symbol, "method": method, "side": side,
                     "candidate_id": cid, "entry_index": entry, "entry_time": int(times[entry]),
                     "entry_fill": entry_fill, "stop_price": stop, "target_price": target, "atr14": atr,
                     "volume": volume, "risk_budget_usd": budget, "planned_risk_usd": volume * risk_per_lot,
                     "entry_conversion_quote_to_usd": quote_to_usd(symbol, entry_mid),
                     "entry_spread_pips": spreads[entry] / pip, "entry_spread_source": spread_sources[entry],
                     "entry_equity_usd": before, "ambiguous": False, "status": "open",
                     "exit_index": np.nan, "exit_time": np.nan, "exit_fill": np.nan, "net_pnl_usd": np.nan,
                     "last_observed_time": int(times[entry]),
                     "closure_crossings": 0, "closure_seconds": 0,
                     "holding_bars": 0, "elapsed_wallclock_seconds": 0,
                     "source_day_boundaries_crossed": 0, "lot_source_day_exposure": 0.,
                     "all_in_net_pnl_usd": np.nan, "swap_cost_usd": np.nan,
                     "net_pnl_before_unknown_swap_usd": np.nan,
                     "pnl_basis": "spread_slippage_commission_included_swap_unknown",
                     "censor_gap_start": np.nan, "censor_gap_end": np.nan, "censor_gap_evidence": "",
                     "result_r": np.nan, "swap_unknown": True, "swap_cost_included": False,
                     "overnight_source_day_crossing": False, "historical_spec_verified": bool(spec.get("historical_spec_verified", False)),
                     "fill_model": "bid_ohlc_bar_spread_market_trigger_proxy", "margin_verified": False}

            def pnl(exit_quote, spread):
                fill = _round_price(exit_quote - sign * slip, tick, up=sign < 0)
                midpoint = exit_quote + sign * spread / 2
                gross_quote = sign * (fill - entry_fill) * contract * volume
                conversion = quote_to_usd(symbol, midpoint)
                return gross_quote * conversion - commission * volume, fill, conversion

            initial_mark = before + pnl(entry_exit_quote, spreads[entry])[0]
            mark(times[entry], entry, cid, initial_mark, initial_mark, before, "entry_liquidation")
            for offset in range(hold):
                idx = entry + offset
                reason = ""
                if idx >= len(b):
                    reason = "censored_data_end"
                elif offset > 0 and gap_status[idx] == 'unknown_gap':
                    reason = "censored_time_gap"
                elif times[idx] + step > end:
                    reason = "censored_period_end"
                elif not valid_price[idx]:
                    reason = "censored_invalid_bar"
                if reason:
                    trade["status"] = reason
                    if reason == 'censored_time_gap':
                        trade.update(censor_gap_start=int(times[idx-1]+step),
                                     censor_gap_end=int(times[idx]), censor_gap_evidence=str(gap_evidence[idx]))
                    blocked, blocking_id = True, cid
                    break
                if offset > 0 and gap_status[idx] == 'scheduled_closure':
                    trade['closure_crossings'] += 1
                    trade['closure_seconds'] += int(gap_seconds[idx])
                trade["last_observed_time"] = int(times[idx] + step)
                trade['holding_bars'] = offset+1
                spread = spreads[idx]
                adjustment = spread if sign < 0 else 0
                oq, hq, lq, cq = (prices[k][idx] + adjustment for k in ("open", "high", "low", "close"))
                gap_stop = sign * (oq - stop) <= 0
                gap_target = sign * (oq - target) >= 0
                hit_stop = lq <= stop if sign > 0 else hq >= stop
                hit_target = hq >= target if sign > 0 else lq <= target
                exit_quote, at_open, label = None, False, ""
                if gap_stop or gap_target:
                    exit_quote, at_open = oq, True
                    label = "stop_gap_open" if gap_stop else "target_gap_open"
                elif hit_stop and hit_target:
                    trade["ambiguous"] = True
                    exit_quote = stop if scenario == "stop_first_lower" else target
                    label = "stop_ambiguous" if scenario == "stop_first_lower" else "target_ambiguous"
                elif hit_stop:
                    exit_quote, label = stop, "stop"
                elif hit_target:
                    exit_quote, label = target, "target"
                elif offset == hold - 1:
                    exit_quote, label = cq, "time_exit"
                # Stop/target cap possible marks while the position exists.
                # The exact favorable/adverse order inside a candle is unknown.
                if at_open:
                    favorable_quote = adverse_quote = oq
                else:
                    favorable_quote = min(hq, target) if sign > 0 else max(lq, target)
                    adverse_quote = max(lq, stop) if sign > 0 else min(hq, stop)
                favorable = before + pnl(favorable_quote, spread)[0]
                adverse = before + pnl(adverse_quote, spread)[0]
                close_equity = before + pnl(cq, spread)[0]
                if exit_quote is not None:
                    net, exit_fill, conversion = pnl(exit_quote, spread)
                    balance = before + net
                    exit_time = int(times[idx] if at_open else times[idx] + step)
                    trade.update(status="closed", exit_reason=label, exit_index=idx, exit_time=exit_time,
                                 exit_time_lower=int(times[idx]), exit_time_upper=exit_time, exit_fill=exit_fill,
                                 exit_conversion_quote_to_usd=conversion, exit_spread_pips=spread/pip,
                                 exit_spread_source=spread_sources[idx], net_pnl_usd=net,
                                 commission_usd=commission*volume, fill_pnl_usd_before_commission=net+commission*volume,
                                 result_r=net/trade["planned_risk_usd"], exit_equity_usd=balance,
                                 holding_bars=offset+1, loss_exceeds_planned_risk=net < -trade["planned_risk_usd"]-1e-8)
                    trade["overnight_source_day_crossing"] = int(times[entry]) // 86400 != exit_time // 86400
                    trade['net_pnl_before_unknown_swap_usd'] = net
                    allow_index = idx if at_open else idx + 1
                    blocking_id = cid
                    close_equity = balance
                mark(times[idx] + (0 if at_open else step), idx, cid, close_equity,
                     min(adverse, close_equity), max(favorable, close_equity), "exit_at_open" if at_open else "bar_envelope")
                if exit_quote is not None:
                    break
            endpoint = trade['exit_time'] if trade['status'] == 'closed' else trade['last_observed_time']
            trade['elapsed_wallclock_seconds'] = int(endpoint-times[entry])
            trade['source_day_boundaries_crossed'] = int(endpoint)//86400-int(times[entry])//86400
            trade['lot_source_day_exposure'] = volume*trade['source_day_boundaries_crossed']
            event.update(status="executed" if trade["status"] == "closed" else trade["status"], volume=volume,
                         risk_budget_usd=budget, planned_risk_usd=trade["planned_risk_usd"])
            event_rows.append(event)
            trade_rows.append(trade)
            scenario_trades.append(trade)
        closed = [t for t in scenario_trades if t["status"] == "closed"]
        profits = sum(max(0., t["net_pnl_usd"]) for t in closed)
        losses = -sum(min(0., t["net_pnl_usd"]) for t in closed)
        observation_start = int(events.signal_time.min()) if len(events) else None
        observation_end = (scenario_trades[-1]["last_observed_time"] if blocked else min(end, int(times[-1])+step)) if len(times) else None
        observed_days = ((observation_end-observation_start)/86400
                         if observation_start is not None and observation_end is not None and observation_end > observation_start else np.nan)
        summary = {"scenario": scenario, "symbol": symbol, "method": method, "side": side,
                   "status": "censored_account_path" if blocked else "provisional_account_scenario",
                   "account_path_complete": not blocked, "account_pnl_promotion_eligible": False,
                   "scenario_is_global_bound": False, "initial_equity_usd": initial,
                   "ending_realized_balance_usd": balance, "net_pnl_usd": balance-initial,
                   "return_pct": 100*(balance/initial-1) if not blocked else np.nan,
                   "n_candidates": len(events), "n_opened": len(scenario_trades), "n_closed": len(closed),
                   "n_ambiguous": sum(t["ambiguous"] for t in scenario_trades),
                   "n_censored": len(scenario_trades)-len(closed),
                   "n_overnight": sum(t["overnight_source_day_crossing"] for t in closed),
                   "n_closure_crossings": sum(t['closure_crossings'] for t in scenario_trades),
                   "closure_seconds": sum(t['closure_seconds'] for t in scenario_trades),
                   "closed_lot_source_day_exposure": sum(t['lot_source_day_exposure'] for t in closed),
                   "open_unresolved_lot_source_day_exposure": sum(t['lot_source_day_exposure'] for t in scenario_trades if t['status'] != 'closed'),
                   "net_pnl_before_unknown_swap_usd": balance-initial,
                   "all_in_net_pnl_usd": np.nan, "swap_cost_usd": np.nan,
                   "pnl_basis": "spread_slippage_commission_included_swap_unknown",
                   "calendar_policy": str(config.get('calendar_policy')),
                   "calendar_historically_verified": False,
                   "holding_clock": "observed_tradable_bars_excluding_approved_closures",
                   "profit_factor": profits/losses if losses else np.nan,
                   "profit_factor_status": "defined" if losses else "no_realized_losses",
                   "gross_profit_usd": profits, "gross_loss_usd": losses,
                   "mean_result_r": float(np.mean([t["result_r"] for t in closed])) if closed else np.nan,
                   "mean_net_pnl_usd": float(np.mean([t["net_pnl_usd"] for t in closed])) if closed else np.nan,
                   "win_rate": sum(t["net_pnl_usd"] > 0 for t in closed)/len(closed) if closed else np.nan,
                   "observed_calendar_days": observed_days,
                   "closed_trades_per_observed_calendar_day": len(closed)/observed_days if observed_days > 0 else np.nan,
                   "frequency_scope": "first_candidate_to_last_observed_account_time_not_full_period_if_censored",
                   "max_drawdown_close_pct": max(q["drawdown_close_pct"] for q in scenario_equity),
                   "max_drawdown_adverse_envelope_pct": max(q["drawdown_adverse_pct"] for q in scenario_equity),
                   "historical_spec_verified": bool(spec.get("historical_spec_verified", False)),
                   "risk_fraction": risk_fraction, "sl_atr": sl_atr, "tp_atr": tp_atr, "max_hold_bars": hold,
                   "assumed_spread_pips": spread_assumed, "slippage_pips_per_side": slip/pip,
                   "commission_per_lot_roundtrip_usd": commission,
                   "swap_unknown": True, "margin_verified": False,
                   "scope": "independent_method_symbol_side_account_not_portfolio",
                   "risk_scope": "per_trade_target_no_daily_or_portfolio_kill_switch"}
        for status in ["skipped_overlap", "skipped_min_lot_risk", "skipped_missing_entry", "skipped_invalid_entry",
                       "skipped_unconfirmed_signal", "skipped_invalid_atr_or_equity", "skipped_stop_geometry", "skipped_account_censored", "skipped_entry_expired"]:
            summary["n_" + status] = sum(e["scenario"] == scenario and e["status"] == status for e in event_rows)
        summaries.append(summary)
    trades = pd.DataFrame(trade_rows) if trade_rows else pd.DataFrame(columns=[
        "scenario", "symbol", "method", "side", "candidate_id", "status", "entry_time", "exit_time", "volume", "net_pnl_usd", "result_r"])
    ledger = pd.DataFrame(event_rows) if event_rows else pd.DataFrame(columns=[
        "scenario", "symbol", "method", "side", "candidate_id", "entry_time", "entry_index", "status"])
    return {"trades": trades, "events": ledger,
            "equity": pd.DataFrame(equity_rows), "summary": pd.DataFrame(summaries)}
