"""Fixed, causal entry-timing diagnostics on an unchanged origin cohort.

Every origin survives as six policy rows. A decision uses only information
available by its confirmation time. Endpoint missingness is independent of
the fill decision: a filled policy never becomes an expired policy because a
later outcome cannot be observed. All prices are bid-bar proxies, not fills.
"""
from __future__ import annotations

import json

import numpy as np
import pandas as pd


POLICIES = ("immediate", "wait1", "wait3", "wait5", "pullback", "breakout")
SPEC_VERSION = "fixed_timing_v1"


def _settings(config: dict) -> dict:
    timing = config.get("timing", {})
    result = {
        "timeframe_seconds": int(config.get("timeframe_seconds", 300)),
        "pip_size": float(config.get("pip_size", .01)),
        "max_entry_delay_seconds": int(config.get("max_entry_delay_seconds", 300)),
        "end_exclusive": int(config.get("end_exclusive", 1767225600)),
        "conditional_wait_bars": int(timing.get("conditional_wait_bars", 10)),
        "pullback_atr": float(timing.get("pullback_atr", .25)),
        "breakout_lookback": int(timing.get("breakout_lookback", 20)),
        "max_entry_offset_bars": int(timing.get("max_entry_offset_bars", 11)),
        "hold_bars": int(timing.get("hold_bars", 10)),
        "deadline_bars": int(timing.get("deadline_bars", 50)),
    }
    if any(not np.isfinite(v) or v <= 0 for k, v in result.items() if k != "max_entry_delay_seconds"):
        raise ValueError("Timing durations, price units and thresholds must be finite and positive")
    if result["max_entry_delay_seconds"] < 0:
        raise ValueError("max_entry_delay_seconds must be nonnegative")
    if result['end_exclusive'] > 1767225600:
        raise ValueError('2026 holdout is locked')
    if result["hold_bars"] != 10 or result["deadline_bars"] != 50:
        raise ValueError("This locked diagnostic uses hold10 and original-deadline50 endpoints")
    cost = config.get("cost", {})
    if cost.get("mode", "assumed") != "assumed":
        raise ValueError("Timing diagnostic requires the unchanged assumed cost scenario")
    cost_values = [float(cost.get("spread_pips", 1.5)),
                   float(cost.get("commission_pips_roundtrip", 0)),
                   2 * float(cost.get("slippage_pips_per_side", .2))]
    if any(not np.isfinite(v) or v < 0 for v in cost_values):
        raise ValueError("Assumed costs must be finite and nonnegative")
    result["roundtrip_cost_pips"] = sum(cost_values)
    return result


def evaluate_timing(bars: pd.DataFrame, candidates: pd.DataFrame, config: dict) -> pd.DataFrame:
    """Evaluate six locked timing policies for each supplied original candidate.

    ``entry_index`` / ``entry_time`` in candidates are the original immediate
    proxy and remain the common reference for fixed waits, conditional P0,
    deadline50 and the maximum 11-bar entry offset. ``common_pool`` copies the
    original ``eligible`` flag; this function does not filter that cohort.

    Unfilled ``expired`` and ``unexecutable`` observations contribute zero only
    to opportunity columns. ``data_unavailable`` and unobserved filled endpoints
    remain NaN. Costs are charged only for a fill with an observed endpoint.
    Return columns without ``_atr`` are pips, not account-currency profit.
    """
    settings = _settings(config)
    required_bars = {"time", "available_time", "open", "high", "low", "close"}
    required_candidates = {"candidate_id", "method", "side", "signal_index", "entry_index",
                           "signal_time", "nominal_close_time", "entry_time", "atr14", "eligible"}
    if missing := required_bars - set(bars):
        raise ValueError(f"Missing bar columns: {sorted(missing)}")
    if missing := required_candidates - set(candidates):
        raise ValueError(f"Missing candidate columns: {sorted(missing)}")
    if candidates.candidate_id.isna().any() or candidates.candidate_id.duplicated().any():
        raise ValueError("candidate_id must be non-null and unique within this batch")
    if not candidates.side.isin(["LONG", "SHORT"]).all():
        raise ValueError("side must be LONG or SHORT")
    step = settings["timeframe_seconds"]
    end = settings["end_exclusive"]
    latency = settings["max_entry_delay_seconds"]
    times = bars.time.to_numpy(np.int64)
    if np.any(times >= 1767225600):
        raise ValueError('2026 holdout price rows are forbidden')
    available = bars.available_time.to_numpy(np.int64)
    if len(times) > 1 and (np.any(np.diff(times) <= 0) or np.any(np.diff(available) < 0)):
        raise ValueError("Bar times must increase and availability must be nondecreasing")
    if np.any(available < times + step):
        raise ValueError("Bar availability cannot precede nominal close")
    if np.any(times % step):
        raise ValueError("Bars must align to the configured timeframe")
    price = {name: bars[name].to_numpy(float) for name in ("open", "high", "low", "close")}
    valid_price = np.logical_and.reduce([np.isfinite(price[name]) for name in price])
    valid_price &= ((price["high"] >= np.maximum(price["open"], price["close"])) &
                    (price["low"] <= np.minimum(price["open"], price["close"])) &
                    (price["low"] <= price["high"]))
    # Prefix counts make an interval coverage check O(1). They do not decide a
    # fill using its outcome interval; outcome coverage is queried only later.
    bad_gap = np.r_[False, np.diff(times) != step] if len(times) else np.array([], dtype=bool)
    gap_sum = np.r_[0, np.cumsum(bad_gap)]
    bad_sum = np.r_[0, np.cumsum(~valid_price)]
    lookback = settings["breakout_lookback"]
    upper = bars.high.rolling(lookback, min_periods=lookback).max().to_numpy()
    lower = bars.low.rolling(lookback, min_periods=lookback).min().to_numpy()
    metadata = {"spec_version": SPEC_VERSION, "policies": list(POLICIES), **settings,
                "source_clock": config.get("clock_basis", "source_clock_unverified"),
                "price_basis": "MT5_bid_bar_proxy_not_observed_fill",
                "cost_basis": "assumed_roundtrip_cost_on_filled_observed_endpoint_only",
                "conditional_observation": "first_closed_bars_from_original_entry",
                "pullback_reclaim": "strictly_later_bar; previous_directional_close<=0; current>0; favorable_body",
                "breakout_reference": "frozen_high_low_20_bars_including_original_signal",
                "endpoint_policy": "fill_status_independent_of_endpoint_censoring",
                "opportunity_policy": "zero_only_known_expired_or_unexecutable; missing_data_remains_NaN"}
    rows = []

    def coverage(left: int, right: int, *, prices: bool = True) -> str:
        if left < 0 or right >= len(times) or right < left:
            return "missing_bars"
        if times[right] + step > end:
            return "research_end_boundary"
        if gap_sum[right + 1] - gap_sum[left + 1]:
            return "time_gap"
        if prices and bad_sum[right + 1] - bad_sum[left]:
            return "invalid_ohlc"
        return ""

    def observable(index: int, expected_time: int, last: int) -> str:
        if index >= len(times):
            return "observation_bars_missing"
        if times[index] != expected_time:
            return "time_gap_during_wait"
        if times[index] + step > end:
            return "research_end_during_wait"
        if not valid_price[index]:
            return "invalid_observation_ohlc"
        if available[index] > last:
            return "observation_unavailable_by_entry_deadline"
        return ""

    for candidate in candidates.to_dict("records"):
        base = int(candidate["entry_index"])
        signal = int(candidate["signal_index"])
        base_time = int(candidate["entry_time"])
        signal_time = int(candidate["signal_time"])
        nominal = int(candidate["nominal_close_time"])
        atr = float(candidate["atr14"])
        sign = 1. if candidate["side"] == "LONG" else -1.
        base_reason = ""
        base_status = "unexecutable"
        if not np.isfinite(atr) or atr <= 0:
            base_reason, base_status = "invalid_signal_atr", "data_unavailable"
        elif base < 0 or base >= len(times):
            base_reason = "original_entry_unavailable"
        elif signal < 0 or signal >= len(times) or base <= signal:
            base_reason = "original_entry_not_after_signal"
        elif base_time != times[base] or base_time < signal_time:
            base_reason = "original_entry_time_invalid"
        elif base_time - nominal > latency:
            base_reason = "original_entry_delay_exceeded"
        elif base_time >= end:
            base_reason = "original_entry_outside_research_period"
        elif not np.isfinite(price["open"][base]):
            base_reason, base_status = "original_open_missing", "data_unavailable"
        p0 = float(price["open"][base]) if 0 <= base < len(times) else np.nan
        latest_entry = base_time + settings["max_entry_offset_bars"] * step
        common = {
            "origin_candidate_id": candidate["candidate_id"], "method": candidate["method"],
            "side": candidate["side"], "week": candidate.get("week"), "year": candidate.get("year"),
            "common_pool": bool(candidate["eligible"]), "original_signal_index": signal,
            "original_entry_index": base, "original_entry_time": base_time,
            "original_signal_time": signal_time, "original_nominal_close_time": nominal,
            "original_price": p0, "atr14": atr, "policy_spec_version": SPEC_VERSION,
            "clock_basis": config.get("clock_basis", "source_clock_unverified"),
            "execution_basis": "bid_bar_open_proxy", "cost_basis": "assumed",
        }
        for name in ("replicate", "symbol", "source_file"):
            if name in candidate:
                common[name] = candidate[name]
        if "origin_candidate_id" in candidate:
            common["matched_origin_candidate_id"] = candidate["origin_candidate_id"]

        for policy in POLICIES:
            row = {**common, "policy": policy, "status": "expired", "status_reason": "no_trigger_within_wait_window",
                   "fill_index": np.nan, "fill_time": np.nan, "fill_price": np.nan,
                   "confirmation_index": np.nan, "confirmation_time": np.nan,
                   "touch_index": np.nan, "touch_confirmation_time": np.nan,
                   "wait_bars": np.nan, "trigger_level": np.nan,
                   "conditional_cost_pips": np.nan}
            fill = None
            if base_reason:
                row.update(status=base_status, status_reason=base_reason)
            elif policy in ("immediate", "wait1", "wait3", "wait5"):
                delay = 0 if policy == "immediate" else int(policy[4:])
                proposed = base + delay
                # Only scheduled times and the execution OPEN matter for a
                # predetermined wait. Its execution bar's later HLC do not.
                why = coverage(base, proposed, prices=False)
                if why:
                    row.update(status="data_unavailable", status_reason="scheduled_" + why)
                elif not np.isfinite(price["open"][proposed]):
                    row.update(status="data_unavailable", status_reason="scheduled_open_missing")
                else:
                    fill = proposed
                    row.update(status="filled", status_reason="scheduled_entry",
                               confirmation_index=signal, confirmation_time=signal_time)
            else:
                threshold = upper[signal] if sign > 0 else lower[signal]
                if policy == "breakout":
                    row["trigger_level"] = threshold
                    if signal < lookback - 1 or not np.isfinite(threshold):
                        row.update(status="data_unavailable", status_reason="frozen_breakout_history_missing")
                    elif np.any(available[signal - lookback + 1:signal + 1] > signal_time):
                        row.update(status="data_unavailable", status_reason="frozen_breakout_history_not_available")
                touched = None
                if row["status"] != "data_unavailable":
                    for offset in range(settings["conditional_wait_bars"]):
                        index = base + offset
                        why = observable(index, base_time + offset * step, latest_entry)
                        if why:
                            row.update(status="data_unavailable", status_reason=why)
                            break
                        if policy == "pullback":
                            adverse = p0 - price["low"][index] if sign > 0 else price["high"][index] - p0
                            if touched is None and adverse >= settings["pullback_atr"] * atr:
                                touched = index
                                row.update(touch_index=index, touch_confirmation_time=int(available[index]),
                                           trigger_level=p0 - sign * settings["pullback_atr"] * atr)
                            trigger = (touched is not None and index > touched and
                                       sign * (price["close"][index - 1] - p0) <= 0 and
                                       sign * (price["close"][index] - p0) > 0 and
                                       sign * (price["close"][index] - price["open"][index]) > 0)
                        else:
                            trigger = sign * (price["close"][index] - threshold) > 0
                        if not trigger:
                            continue
                        confirm = int(available[index])
                        row.update(confirmation_index=index, confirmation_time=confirm)
                        proposed = max(index + 1, int(np.searchsorted(times, confirm, side="left")))
                        if proposed >= len(times):
                            row.update(status="data_unavailable", status_reason="confirmation_entry_bar_missing")
                            break
                        why = coverage(base, proposed, prices=False)
                        if why:
                            row.update(status="data_unavailable", status_reason="confirmation_" + why)
                        elif times[proposed] - (times[index] + step) > latency:
                            row.update(status="unexecutable", status_reason="confirmation_entry_delay_exceeded")
                        elif times[proposed] > latest_entry:
                            row.update(status="unexecutable", status_reason="latest_entry_deadline_exceeded")
                        elif not np.isfinite(price["open"][proposed]):
                            row.update(status="data_unavailable", status_reason="confirmation_open_missing")
                        else:
                            fill = proposed
                            row.update(status="filled", status_reason="conditional_confirmed")
                        break
            if fill is not None:
                row.update(fill_index=fill, fill_time=int(times[fill]), fill_price=float(price["open"][fill]),
                           wait_bars=(int(times[fill]) - base_time) // step,
                           conditional_cost_pips=settings["roundtrip_cost_pips"])
            for endpoint, final in (("hold10", None if fill is None else fill + 9),
                                    ("deadline50", base + 49)):
                gross = net = gross_atr = net_atr = np.nan
                why = "no_fill"
                complete = False
                if fill is not None:
                    why = coverage(fill, final)
                    complete = not why
                    if complete:
                        move = sign * (price["close"][final] - price["open"][fill])
                        gross = move / settings["pip_size"]
                        net = gross - settings["roundtrip_cost_pips"]
                        gross_atr = move / atr
                        net_atr = (move - settings["roundtrip_cost_pips"] * settings["pip_size"]) / atr
                row["endpoint_complete_" + endpoint] = complete
                row["endpoint_reason_" + endpoint] = why
                row["endpoint_time_" + endpoint] = int(times[final]) + step if complete else np.nan
                for prefix, value in (("gross", gross), ("net", net),
                                      ("gross_atr", gross_atr), ("net_atr", net_atr)):
                    # Keep both endpoint names visually adjacent for CSV use.
                    key = f"{prefix}_{endpoint}" if not prefix.endswith("_atr") else f"{prefix[:-4]}_{endpoint}_atr"
                    row[key] = value
                    row["opp_" + key] = 0.0 if row["status"] in ("expired", "unexecutable") else value
            rows.append(row)
    result = pd.DataFrame(rows)
    if result.empty:
        result = pd.DataFrame(columns=["origin_candidate_id", "policy", "method", "side", "week", "year",
            "common_pool", "status", "status_reason", "fill_index", "fill_time", "confirmation_time", "wait_bars",
            *[f"{prefix}{metric}_{endpoint}{suffix}" for endpoint in ("hold10", "deadline50")
              for prefix in ("", "opp_") for metric in ("gross", "net") for suffix in ("", "_atr")]])
    # A serializable artifact attribute records policy definitions without
    # copying a long JSON object onto each of the ~100k diagnostic rows.
    result.attrs["timing_metadata"] = json.loads(json.dumps(metadata))
    return result
