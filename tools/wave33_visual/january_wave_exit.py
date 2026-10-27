"""Entry-fixed January wave/exit diagnostics. Reads frozen CSV only; no MT5 calls.

Entry features use the ORDER event snapshot, with event-row order and source
known_at/closed_at cutoffs. Outcomes use FILL/EXIT and immutable initial SL.
OHLC excursions are bounded BID proxies, not executable tick simulations.
"""
from __future__ import annotations

import json
import math
import csv
from pathlib import Path

import numpy as np
import pandas as pd

BASE = Path("reports/backtest/analysis/wave33_january_20261026")
OUT = BASE / "wave_exit"
FMT = "%Y.%m.%d %H:%M:%S"


def read(path):
    if path.name == "daytrade.csv":
        # MQL writer does not quote semicolons inside free-text reason. The
        # remaining nineteen typed trailing columns have no delimiters.
        with path.open(encoding="utf-8-sig", newline="") as stream:
            rows = list(csv.reader(stream, delimiter=";"))
        header = rows[0]
        assert len(header) == 24
        repaired = [r[:4] + [";".join(r[4:len(r)-19])] + r[-19:] for r in rows[1:]]
        assert all(len(r) == 24 for r in repaired)
        frame = pd.DataFrame(repaired, columns=header)
        frame.attrs["delimiter_repair_rows"] = sum(len(r) != 24 for r in rows[1:])
        return frame
    return pd.read_csv(path, sep=";", low_memory=False).fillna("")


def ts(value):
    return pd.to_datetime(value, format=FMT, errors="coerce")


def num(value):
    try:
        v = float(value)
        return v if math.isfinite(v) else np.nan
    except (TypeError, ValueError):
        return np.nan


def mins(a, b):
    return (ts(a) - ts(b)).total_seconds() / 60 if pd.notna(ts(a)) and pd.notna(ts(b)) else np.nan


def clean(value):
    if isinstance(value, dict):
        return {str(k): clean(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [clean(v) for v in value]
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating, float)):
        return float(value) if math.isfinite(value) else None
    if isinstance(value, (np.bool_,)):
        return bool(value)
    if isinstance(value, pd.Timestamp):
        return str(value)
    return value


def metrics(frame):
    r = frame.net_r.astype(float)
    cash = frame.net_cash.astype(float)
    win = r > 1e-9
    loss = r < -1e-9
    return dict(n=len(frame), wins=int(win.sum()), losses=int(loss.sum()),
                breakeven=int((~win & ~loss).sum()), win_rate=float(win.mean()) if len(r) else None,
                net_r=r.sum(), mean_r=r.mean(), net_cash=cash.sum(),
                pf_r=r[win].sum() / -r[loss].sum() if loss.any() else None,
                pf_cash=cash[cash > 0].sum() / -cash[cash < 0].sum() if (cash < 0).any() else None)


def md(frame):
    def fmt(v):
        return f"{v:.4g}" if isinstance(v, (float, np.floating)) else str(v).replace("|", "/")
    return "\n".join(["| " + " | ".join(frame.columns) + " |", "| " + " | ".join(["---"] * len(frame.columns)) + " |"] +
                     ["| " + " | ".join(fmt(v) for v in row) + " |" for row in frame.itertuples(index=False, name=None)])


def normalize_pivots(frame):
    """Ambiguous simultaneous H/L are barriers; same-side extrema normalized."""
    result = []
    ambiguous = 0
    ambiguous_times = set(frame.loc[frame.pt.duplicated(keep=False), "pt"])
    last_ambiguous = None
    for p in frame.sort_values("pt").itertuples(index=False):
        if p.pt in ambiguous_times:
            result = []
            if p.pt != last_ambiguous:
                ambiguous += 1
                last_ambiguous = p.pt
            continue
        high = p.observed_pivot_label in ("H", "HH", "LH")
        price = num(p.observed_pivot_price)
        if result and result[-1][0] == high:
            if (high and price > result[-1][1]) or (not high and price < result[-1][1]):
                result[-1] = (high, price)
        else:
            result.append((high, price))
    return result, ambiguous


def run_one(path):
    run = path.name
    e = read(path / "events.csv")
    e["sequence"] = np.arange(len(e))
    e["at"] = ts(e.event_at)
    b = read(path / "lower_bars.csv")
    for column in ("bar_time", "closed_at", "known_at"):
        b[column] = ts(b[column])
    for column in ("open", "high", "low", "close"):
        b[column] = pd.to_numeric(b[column])
    assert b.bar_time.is_unique and b.bar_time.is_monotonic_increasing
    assert (b.closed_at - b.bar_time).eq(pd.Timedelta(minutes=1)).all()
    prev = b.close.shift()
    b["tr"] = pd.concat([b.high - b.low, (b.high - prev).abs(), (b.low - prev).abs()], axis=1).max(axis=1)
    all_pivots = e.loc[e.event_type == "PIVOT_CONFIRMED"].copy()
    all_pivots["pt"] = ts(all_pivots.observed_pivot_time)
    all_pivots["pk"] = ts(all_pivots.observed_pivot_known_at)
    pivots = all_pivots.loc[all_pivots.observed_pivot_tf == "PERIOD_M1"]
    fills = e.loc[e.event_type == "FILL"]
    exits = e.loc[e.event_type == "EXIT"]
    assert fills.setup_id.is_unique and exits.setup_id.is_unique
    assert set(fills.setup_id) == set(exits.setup_id)
    day = read(path / "daytrade.csv") if (path / "daytrade.csv").exists() else None
    raw = read(path / "raw_deals.csv") if (path / "raw_deals.csv").exists() else None
    chop = read(path / "chop.csv") if (path / "chop.csv").exists() else None
    result = []
    issues = []
    for _, f in fills.iterrows():
        sid = f.setup_id
        x = exits.loc[exits.setup_id == sid].iloc[0]
        orders = e.loc[(e.event_type == "ORDER") & (e.setup_id == sid) & (e.sequence < f.sequence)]
        assert len(orders) == 1
        o = orders.iloc[0]
        ft, xt = ts(f.fill_at), ts(x.exit_at)
        source_fill_at = ft
        if raw is not None:
            dr = raw.loc[raw.setup_id == sid]
            din = dr.loc[dr.entry == "DEAL_ENTRY_IN"]
            dout = dr.loc[dr.entry == "DEAL_ENTRY_OUT"]
            assert len(din) and len(dout)
            # Naive source clock: Unix values decode tester/source time; not asserted UTC.
            ft = pd.Timestamp(int(din.time_msc.astype(float).min()), unit="ms")
            xt = pd.Timestamp(int(dout.time_msc.astype(float).max()), unit="ms")
        sign = 1 if f.direction == "LONG" else -1
        entry, sl = num(f.entry_price), num(f.sl_price)
        risk = abs(entry - sl)
        assert risk > 0 and sign * (entry - sl) > 0
        dr_final = None
        if day is not None:
            dr_frozen = day.loc[(day.setup_id == sid) & (day.event == "DAYTRADE_RISK_FROZEN")].iloc[0]
            dr_final = day.loc[(day.setup_id == sid) & (day.event == "DAYTRADE_POSITION_CLOSED")].iloc[-1]
            assert abs(num(dr_frozen.original_sl) - sl) < 1e-7
            assert abs(num(dr_frozen.fixed_risk_price) - risk) < 1e-7
        riskmoney, cash = num(x.execution_initial_risk_money), num(x.execution_net_cash)
        assert riskmoney > 0
        r = cash / riskmoney
        assert abs(r - num(x.realized_r)) < 1e-7
        cutoff = ts(o.event_at)
        signal_close = ts(o.signal_at)
        # If same-time delayed bar batches exist, ORDER's signal-close prevents future batch use.
        close_cut = min(cutoff, signal_close) if pd.notna(signal_close) else cutoff
        avail = b.loc[(b.known_at <= cutoff) & (b.closed_at <= close_cut)]
        assert (avail.known_at <= cutoff).all() and (avail.closed_at <= cutoff).all()
        origin, peak = ts(o.wave1_start_time), ts(o.wave1_peak_time)
        origin_price, peak_price = num(o.wave1_start_price), num(o.wave1_peak_price)
        span = sign * (peak_price - origin_price)
        assert span > 0
        duration = mins(o.wave1_peak_time, o.wave1_start_time)
        age = mins(o.event_at, o.wave1_peak_time)
        wb = avail.loc[(avail.bar_time >= origin) & (avail.bar_time <= peak)]
        path_prices = np.r_[origin_price, wb.close.to_numpy(), peak_price]
        delta = np.diff(path_prices)
        path_len = np.abs(delta).sum()
        adverse = np.maximum(0, -sign * delta).sum()
        wp = pivots.loc[(pivots.pt > origin) & (pivots.pt < peak) & (pivots.pk <= cutoff) & (pivots.sequence < o.sequence)]
        norm, amb = normalize_pivots(wp)
        pp = np.r_[origin_price, [p[1] for p in norm], peak_price]
        pivot_backtrack = np.maximum(0, -sign * np.diff(pp)).sum() / span
        candidate = e.loc[(e.setup_id == sid) & (e.event_type == "WAVE1_BREAK")].iloc[0]
        preorigin_raw = all_pivots.loc[(all_pivots.observed_pivot_tf == o.upper_tf) &
                                       (all_pivots.pt < origin) & (all_pivots.pk <= candidate["at"]) &
                                       (all_pivots.sequence < candidate.sequence)]
        preorigin, pre_amb = normalize_pivots(preorigin_raw)
        pre8 = preorigin[-8:]
        pre8_complete = len(pre8) == 8
        preleg = np.median([abs(bb[1]-aa[1]) for aa, bb in zip(pre8, pre8[1:])]) if pre8_complete else np.nan
        highs = [p[1] for p in pre8 if p[0]]
        lows = [p[1] for p in pre8 if not p[0]]
        struct_deltas = [b-a for series in (highs, lows) for a, b in zip(series, series[1:])]
        preagreement = np.mean([-sign * delta > 0 for delta in struct_deltas]) if pre8_complete else np.nan
        oldouter = max(highs) if sign > 0 and highs else (min(lows) if lows else np.nan)
        atr = avail.tr.tail(14).mean() if len(avail) >= 14 else np.nan
        row = dict(run=run, setup_id=sid, symbol=f.symbol, upper_tf=f.upper_tf, lower_tf=f.lower_tf,
                   direction=f.direction, order_at=str(cutoff), signal_at=str(signal_close), fill_at=str(ft),
                   event_fill_at=str(source_fill_at), exit_at=str(xt), month=ft.strftime("%Y-%m"),
                   entry=entry, initial_sl=sl, exit_sl=num(x.sl_price), tp_at_fill=num(f.tp_price),
                   net_cash=cash, initial_risk_money=riskmoney, net_r=r,
                   outcome="WIN" if r > 1e-9 else ("LOSS" if r < -1e-9 else "BREAKEVEN"),
                   exit_reason=x.exit_reason, exit_deal_reason=x.exit_deal_reason,
                   holding_minutes=(xt - ft).total_seconds() / 60,
                   initial_risk_price=risk, wave1_span=span, wave1_duration_min=duration,
                   wave1_origin_at=str(origin), wave1_peak_at=str(peak),
                   wave1_peak_known_at=o.wave1_peak_known_at,
                   wave1_close_path_er=span / path_len if path_len else np.nan,
                   wave1_close_backtrack=adverse / span,
                   wave1_m1_pivot_backtrack=pivot_backtrack if not amb else np.nan,
                   wave1_m1_pivot_count=len(norm), wave1_ambiguous_barriers=amb,
                   wave1_m1_bars=len(wb), wave1_revision=num(o.wave1_revision),
                   preorigin_upper_pivot_count=len(pre8), preorigin_upper_complete8=int(pre8_complete),
                   preorigin_countertrend_agreement=preagreement,
                   wave1_over_preorigin_leg_median=span / preleg if preleg > 0 else np.nan,
                   wave1_peak_margin_over_pre8_outer=sign * (peak_price - oldouter) / span if pre8_complete else np.nan,
                   wave2_extreme_time=o.wave2_extreme_time, wave2_extreme_known_at=o.wave2_extreme_known_at,
                   wave2_depth=num(o.retracement_ratio),
                   wave2_extreme_latency_min=mins(o.event_at, o.wave2_extreme_time),
                   wave2_known_latency_min=mins(o.event_at, o.wave2_extreme_known_at),
                   wave2_age_from_peak_min=age,
                   wave2_age_over_wave1_duration=age / duration if duration > 0 else np.nan,
                   peak_known_to_order_min=mins(o.event_at, o.wave1_peak_known_at),
                   structure_known_to_order_min=mins(o.event_at, o.lower_structure_known_at),
                   signal_to_fill_seconds=(ft - signal_close).total_seconds() if pd.notna(signal_close) else np.nan,
                   order_to_fill_seconds=(ft - cutoff).total_seconds(),
                   order_entry_progress=(sign * (num(o.entry_price) - origin_price)) / span,
                   actual_entry_progress=(sign * (entry - origin_price)) / span,
                   actual_wave1_room_r=sign * (peak_price - entry) / risk,
                   initial_risk_over_wave1=risk / span,
                   intended_rr=num(o.intended_rr), recorded_actual_rr=num(o.actual_rr),
                   actual_tp_r=sign * (num(f.tp_price) - entry) / risk if num(f.tp_price) > 0 else np.nan,
                   tp_extended_to_wave1=num(o.tp_extended_to_wave1),
                   obstacle_distance_r=num(o.obstacle_distance_r), obstacle_source=o.nearest_obstacle_source,
                   obstacle_tf=o.nearest_obstacle_tf, h1_direction=o.h1_direction,
                   candle_body_ratio=num(o.candle_body_ratio), candle_body_atr=num(o.candle_body_atr),
                   lower_entry_stage=o.lower_entry_stage, lower_recognition=o.lower_recognition,
                   lower_trigger=o.trigger_type,
                   spread_over_risk=num(o.spread_points) / num(o.risk_points) if num(o.risk_points) > 0 else np.nan,
                   atr14=atr, risk_over_m1_atr14=risk / atr if atr > 0 else np.nan,
                   wave1_span_over_m1_atr14=span / atr if atr > 0 else np.nan,
                   complete_preentry_bars=len(avail))
        for window in (15, 60):
            pre = avail.loc[avail.bar_time >= close_cut - pd.Timedelta(minutes=window)]
            width = pre.high.max() - pre.low.min() if len(pre) else np.nan
            den = pre.close.diff().abs().sum()
            er = abs(pre.close.iloc[-1] - pre.close.iloc[0]) / den if len(pre) > 1 and den else np.nan
            row[f"pre{window}_bars"] = len(pre)
            row[f"pre{window}_range_over_atr"] = width / atr if atr > 0 else np.nan
            row[f"pre{window}_range_over_risk"] = width / risk
            row[f"pre{window}_close_er"] = er
        if chop is not None:
            cs = chop.loc[(chop.setup_id == sid) & (ts(chop.evaluation_at) <= cutoff)]
            cs = cs.loc[cs.source_event.isin(["CHOP_ENTRY_FILTER", "SIGNAL", "ORDER", "RISK_CHECK", "WAVE1_PEAK_CONFIRMED", "WAVE1_EXTENDED_CONFIRMED"])]
            row["recorded_chop_backtrack"] = num(cs.iloc[-1].backtrack_ratio) if len(cs) else np.nan
            row["recorded_chop_status"] = cs.iloc[-1].status if len(cs) else ""
            if row["recorded_chop_status"] == "UNAVAILABLE":
                row["recorded_chop_backtrack"] = np.nan
        sg = e.loc[(e.setup_id == sid) & (e.sequence > f.sequence) & (e.sequence <= x.sequence)]
        row["opposite_armed_during_trade"] = int(sg.event_type.eq("OPPOSITE_WAVE1_ARMED").any())
        row["opposite_close_requested"] = int(sg.event_type.eq("OPPOSITE_CLOSE_REQUEST").any())
        row["native_max_favorable_r"] = num(dr_final.max_favorable_r) if dr_final is not None else np.nan
        overlap = b.loc[(b.closed_at > ft) & (b.bar_time < xt)]
        complete = overlap.loc[(overlap.bar_time >= ft) & (overlap.closed_at <= xt)]
        assert (complete.bar_time >= ft).all() and (complete.closed_at <= xt).all()
        exitprice = num(x.exit_price)
        endr = sign * (exitprice - entry) / risk
        for label, bars in (("lower", complete), ("upper", overlap)):
            favorable = (bars.high - entry) / risk if sign > 0 else (entry - bars.low) / risk
            adverse_r = (entry - bars.low) / risk if sign > 0 else (bars.high - entry) / risk
            row[f"mfe_{label}_r"] = max(0, endr, favorable.max() if len(bars) else 0)
            row[f"mae_{label}_r"] = max(0, -endr, adverse_r.max() if len(bars) else 0)
        row["path_full_bars"] = len(complete)
        row["path_overlap_bars"] = len(overlap)
        row["boundary_extrema_uncertain"] = int(len(overlap) > len(complete))
        row["path_max_gap_min"] = max(0, overlap.bar_time.diff().dt.total_seconds().max() / 60 - 1) if len(overlap) > 1 else 0
        assert row["mfe_lower_r"] <= row["mfe_upper_r"] + 1e-8
        assert row["mae_lower_r"] <= row["mae_upper_r"] + 1e-8
        nmfe = row["native_max_favorable_r"]
        if pd.notna(nmfe):
            row["one_r_reach_class"] = "REACHED_1R_NATIVE" if nmfe >= 1 - 1e-9 else "DID_NOT_REACH_1R_NATIVE"
        elif row["mfe_lower_r"] >= 1 - 1e-9:
            row["one_r_reach_class"] = "REACHED_1R_COMPLETE_BAR_BID_PROXY"
        elif row["mfe_upper_r"] < 1 - 1e-9:
            row["one_r_reach_class"] = "DID_NOT_REACH_1R_BID_PROXY"
        else:
            row["one_r_reach_class"] = "UNKNOWN_BOUNDARY_BAR_1R"
        # Initial-SL-before-1R is an OHLC sequence diagnostic, explicitly not a re-execution.
        first_one = first_stop = None
        for _, bb in complete.iterrows():
            hi = (bb.high - entry) / risk if sign > 0 else (entry - bb.low) / risk
            lo = (entry - bb.low) / risk if sign > 0 else (bb.high - entry) / risk
            if first_one is None and hi >= 1 - 1e-9:
                first_one = bb.bar_time
            if first_stop is None and lo >= 1 - 1e-9:
                first_stop = bb.bar_time
        row["first_complete_1r_bar"] = str(first_one) if first_one is not None else ""
        row["first_complete_initial_sl_bar"] = str(first_stop) if first_stop is not None else ""
        if r < 0:
            if row["one_r_reach_class"].startswith("DID_NOT"):
                row["loss_path_class"] = "LOSS_WITHOUT_1R"
            elif row["one_r_reach_class"].startswith("REACHED"):
                row["loss_path_class"] = "REACHED_1R_THEN_LOSS"
            else:
                row["loss_path_class"] = "LOSS_1R_ORDER_UNKNOWN"
        else:
            row["loss_path_class"] = "NONLOSS"
        result.append(row)
    frame = pd.DataFrame(result).sort_values("fill_at").reset_index(drop=True)
    frame["loss_streak_at_fill_order"] = 0
    current = 0
    for i in frame.index:
        current = current + 1 if frame.loc[i, "net_r"] < -1e-9 else 0
        frame.loc[i, "loss_streak_at_fill_order"] = current
    audit = dict(run=run, fills=len(fills), exits=len(exits), unique_setup_ids=bool(fills.setup_id.is_unique),
                 f0=str(frame.fill_at.min()), f1=str(frame.fill_at.max()),
                 immutable_sl_source="FILL, checked against DAYTRADE_RISK_FROZEN when available",
                 timestamp_source="raw_deals.time_msc" if raw is not None else "FILL.fill_at / EXIT.exit_at (second precision)",
                 order_snapshot_source="ORDER event before FILL, never EXIT wave fields",
                 path_full_bar_rule="bar_time >= actual_fill AND closed_at <= actual_exit",
                 path_upper_rule="overlapping boundary bars included; extrema may predate fill/postdate exit",
                 price_proxy="M1 BID OHLC; SHORT ask/cost and boundary intrabar ordering unknown",
                 source_clock="broker/tester source clock; UTC mapping not verified",
                 postexit_bars_used_for_lower=0,
                 daytrade_delimiter_repair_rows=day.attrs.get("delimiter_repair_rows", 0) if day is not None else 0,
                 issues=issues)
    return frame, audit


def cuts(frame):
    """Fixed natural-scale cuts, declared together; no threshold scan or best pick."""
    return {
        "direction": frame.direction,
        "wave1_duration": pd.cut(frame.wave1_duration_min, [-np.inf, 15, 30, 60, np.inf], labels=["<=15m", "15-30m", "30-60m", ">60m"]),
        "wave2_depth": pd.cut(frame.wave2_depth, [-np.inf, .382, .5, .618, np.inf], labels=["<=38.2%", "38.2-50%", "50-61.8%", ">61.8%"]),
        "wave2_age_over_wave1": pd.cut(frame.wave2_age_over_wave1_duration, [-np.inf, 1, 2, np.inf], labels=["<=1x", "1-2x", ">2x"]),
        "wave2_extreme_latency": pd.cut(frame.wave2_extreme_latency_min, [-np.inf, 5, 15, 30, np.inf], labels=["<=5m", "5-15m", "15-30m", ">30m"]),
        "wave1_close_ER": pd.cut(frame.wave1_close_path_er, [-np.inf, .25, .5, .75, np.inf], labels=["<=.25", ".25-.50", ".50-.75", ">.75"]),
        "wave1_pivot_backtrack": pd.cut(frame.wave1_m1_pivot_backtrack, [-np.inf, .5, 1, 2, np.inf], labels=["<=.5", ".5-1", "1-2", ">2"]),
        "entry_progress": pd.cut(frame.actual_entry_progress, [-np.inf, .5, .75, 1, np.inf], labels=["<=50%", "50-75%", "75-100%", ">100%"]),
        "wave1_room_R": pd.cut(frame.actual_wave1_room_r, [-np.inf, 0, .5, 1, np.inf], labels=["<=0R", "0-.5R", ".5-1R", ">1R"]),
        "risk_ATR": pd.cut(frame.risk_over_m1_atr14, [-np.inf, 1, 2, 4, np.inf], labels=["<=1ATR", "1-2ATR", "2-4ATR", ">4ATR"]),
        "candle_body_ATR": pd.cut(frame.candle_body_atr, [-np.inf, .5, 1, 2, np.inf], labels=["<=.5ATR", ".5-1ATR", "1-2ATR", ">2ATR"]),
        "spread_risk": pd.cut(frame.spread_over_risk, [-np.inf, .05, .1, np.inf], labels=["<=5%R", "5-10%R", ">10%R"]),
        "pre15_ER": pd.cut(frame.pre15_close_er, [-np.inf, .25, .5, np.inf], labels=["<=.25", ".25-.5", ">.5"]),
        "pre60_ER": pd.cut(frame.pre60_close_er, [-np.inf, .25, .5, np.inf], labels=["<=.25", ".25-.5", ">.5"]),
        "wave1_revision": frame.wave1_revision.map(lambda v: "extended" if v > 0 else "original"),
        "lower_stage": frame.lower_entry_stage,
        "h1_logged_direction": frame.h1_direction,
        "tp_extended": frame.tp_extended_to_wave1,
        "preorigin_countertrend_agreement": pd.cut(frame.preorigin_countertrend_agreement, [-np.inf, .5, .75, 1], labels=["<=50%", "50-75%", ">75%"]),
        "wave1_vs_preleg": pd.cut(frame.wave1_over_preorigin_leg_median, [-np.inf, 1, 2, np.inf], labels=["<=1x", "1-2x", ">2x"]),
        "wave1_breaks_pre8_outer": frame.wave1_peak_margin_over_pre8_outer.map(lambda v: "UNAVAILABLE" if pd.isna(v) else ("YES" if v > 0 else "NO")),
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frames, audits = [], []
    for path in sorted((BASE / "source").iterdir()):
        if (path / "events.csv").exists():
            frame, audit = run_one(path)
            frames.append(frame)
            audits.append(audit)
    allf = pd.concat(frames, ignore_index=True)
    allf.to_csv(OUT / "features.csv", index=False, encoding="utf-8-sig")
    groups, strat, means, losses, streaks = [], [], [], [], []
    for (run, month), df in allf.groupby(["run", "month"], sort=True):
        groups.append(dict(run=run, month=month, **metrics(df)))
        for feature, values in cuts(df).items():
            labels = values.astype(object).map(lambda v: "UNAVAILABLE" if pd.isna(v) else str(v))
            for label in sorted(labels.unique()):
                ss = df.loc[labels.eq(label)]
                strat.append(dict(run=run, month=month, feature=feature, group=label, **metrics(ss)))
        numeric = [c for c in df.select_dtypes(include=[np.number]).columns if c not in ("net_cash", "net_r", "initial_risk_money")]
        for feature in numeric:
            for outcome, ss in df.groupby("outcome"):
                values = ss[feature].dropna()
                means.append(dict(run=run, month=month, outcome=outcome, feature=feature, n=len(values),
                                  median=values.median(), mean=values.mean(), min=values.min(), max=values.max()))
        for cls, ss in df.loc[df.outcome == "LOSS"].groupby("loss_path_class"):
            losses.append(dict(run=run, month=month, loss_path_class=cls, **metrics(ss)))
        # Local streak within the month; fill order, matched close-order also reported.
        for ordering in ("fill_at", "exit_at"):
            ordered = df.sort_values(ordering)
            current = []
            blocks = []
            for _, row in ordered.iterrows():
                if row.net_r < -1e-9:
                    current.append(row)
                elif current:
                    blocks.append(current)
                    current = []
            if current:
                blocks.append(current)
            longest = max(blocks, key=len) if blocks else []
            streaks.append(dict(run=run, month=month, ordering=ordering, max_loss_streak=len(longest),
                                start=longest[0][ordering] if longest else "", end=longest[-1][ordering] if longest else "",
                                net_r=sum(r.net_r for r in longest), ids=[r.setup_id for r in longest]))
    for name, rows in (("monthly", groups), ("stratifications", strat), ("outcome_feature_statistics", means), ("loss_paths", losses)):
        pd.DataFrame(rows).to_csv(OUT / f"{name}.csv", index=False, encoding="utf-8-sig")
    payload = dict(monthly=groups, loss_paths=losses, streaks=streaks, audits=audits,
                   scope="Descriptive fixed-entry analysis; no strategy changes, threshold search, or native backtests.",
                   nulls=["Gold January versions differ in timing/exits; do not pool trades as independent observations.",
                          "Only USD has February/March in frozen inputs; Gold has no out-of-month validation here.",
                          "Small January n (especially winners) prevents reliable feature selection.",
                          "M1 BID extrema in boundary minutes are uncertain; do not claim fill/exit tick path from OHLC.",
                          "Recorded current H1 classification is not a new H1/H4 market-context reconstruction.",
                          "Native v190 MFE is observed while held, not hypothetical post-exit upside."])
    (OUT / "summary.json").write_text(json.dumps(clean(payload), ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")
    m = pd.DataFrame(groups)
    lines = ["# January wave geometry and actual-holding exit paths", "", "Fixed natural cuts; descriptive only. No EA launch or mutation.", "", md(m), "", "## Loss paths", "", md(pd.DataFrame(losses)), "", "## Streaks", "", md(pd.DataFrame([{k:v for k,v in s.items() if k != 'ids'} for s in streaks])), "", "## Boundaries and nulls", ""]
    lines.extend("- " + item for item in payload["nulls"])
    lines += ["", "All actual trades, immutable SL, causal entry metrics and MFE bounds: features.csv. Full fixed-bin results: stratifications.csv. Per-outcome medians: outcome_feature_statistics.csv. Native/CSV audits: summary.json."]
    (OUT / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    print(m.to_string(index=False))
    print(pd.DataFrame(losses).to_string(index=False))
    print("Written", OUT)


if __name__ == "__main__":
    main()
