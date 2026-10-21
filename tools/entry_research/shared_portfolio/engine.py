"""Chronological shared-equity admission around the frozen single-trade model.

Future paths are outcome schedules, not entry filters. Only entry geometry is
read at admission; every subsequent mark is consumed at its recorded time.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from ..account_replay.execution import _round_price, quote_to_usd
from .path import trade_path

LOCK = 1767225600


def notional_usd(symbol, volume, contract, midpoint):
    return volume * contract * (midpoint if symbol.endswith('USD') else 1.)


def simulate_shared(bars, candidates, specs, execution, config, *, start, end,
                    mode='hedging', scenario='stop_first_lower'):
    if end > LOCK or start >= end or mode not in ['hedging', 'block_opposite']:
        raise ValueError('Invalid shared replay interval or mode')
    if candidates.candidate_id.duplicated().any():
        raise ValueError('Candidate IDs must be globally unique')
    for frame in bars.values():
        if (frame.time >= LOCK).any() or not frame.time.is_monotonic_increasing or frame.time.duplicated().any():
            raise ValueError('Forbidden holdout or unordered prices')
    initial = float(config['initial_equity'])
    if initial <= 0 or not 0 < config['risk_fraction'] < 1 or config['assumed_leverage'] <= 0:
        raise ValueError('Invalid capital configuration')
    arrays = {s: {k: f[k].to_numpy() for k in ['time', 'open', 'close', 'spread']} for s, f in bars.items()}
    event_rows, trades, equity, positions = [], [], [], {}
    scheduled = {}
    order = {cell: i for i, cell in enumerate(config['cell_order'])}
    for candidate in candidates.to_dict('records'):
        event = {k: candidate[k] for k in ['candidate_id', 'cell_id', 'symbol', 'method', 'side', 'signal_time', 'entry_time']}
        event.update(status='pending', scenario=scenario, mode=mode)
        event_rows.append(event)
        observed = candidate['entry_time'] if candidate['entry_time'] > 0 else candidate['signal_time']
        if observed < start or observed >= end:
            event['status'] = 'outside_replay_period'
        elif not candidate.get('filter_pass', True):
            event['status'] = 'excluded_shallow_breakout'
        elif not candidate.get('calendar_pass', True):
            event['status'] = 'excluded_calendar_pause'
        else:
            scheduled.setdefault(int(observed), []).append((candidate, event))
    timeline = {int(start), int(end), *scheduled.keys()}
    for frame in bars.values():
        for column in [frame.time, frame.time + execution['timeframe_seconds']]:
            timeline.update(int(t) for t in column if start <= t <= end)
    balance, peak, day_start, day, peak_halted = initial, initial, initial, None, False
    complete, censor_reason, censor_time = True, '', None

    def quote(symbol, time, at_close=False):
        a, spec = arrays[symbol], specs[symbol]
        idx = int(np.searchsorted(a['time'], time, side='left' if at_close else 'right')) - 1
        if idx < 0:
            raise ValueError('No observed quote for an open position')
        at_open = a['time'][idx] == time
        # If no new open exists, use only a bar that has already closed.
        if not at_open and a['time'][idx] + execution['timeframe_seconds'] > time:
            raise ValueError('Unconfirmed close cannot value current equity')
        price = float(a['open'][idx] if at_open else a['close'][idx])
        points = float(a['spread'][idx])
        assumed = execution['assumed_spread_pips'][symbol]
        spread = points * spec['point'] if np.isfinite(points) and points > 0 else assumed * spec['pip_size']
        stale = (a['time'][idx] + execution['timeframe_seconds'] < time) if at_close else not at_open
        return price, spread, price + spread / 2, stale

    def floating(position, time):
        tr, spec = position['trade'], specs[position['trade']['symbol']]
        bid, spread, mid, stale = quote(tr['symbol'], time)
        sign = 1 if tr['side'] == 'LONG' else -1
        exit_quote = bid + (spread if sign < 0 else 0)
        slip = execution['slippage_pips_per_side'] * spec['pip_size']
        fill = _round_price(exit_quote - sign * slip, spec['tick_size'], up=sign < 0)
        pnl = (sign * (fill - tr['entry_fill']) * spec['contract_size'] * tr['volume']
               * quote_to_usd(tr['symbol'], mid)
               - execution.get('commission_per_lot_roundtrip_usd', 0) * tr['volume'])
        return pnl

    def exposures(time, at_close=False):
        risk = sum(p['trade']['planned_risk_usd'] for p in positions.values())
        gross, currency, stale = 0., dict(USD=0., JPY=0., CHF=0., AUD=0.), 0
        for p in positions.values():
            tr, spec = p['trade'], specs[p['trade']['symbol']]
            _, _, mid, aged = quote(tr['symbol'], time, at_close=at_close)
            stale += int(aged)
            value = notional_usd(tr['symbol'], tr['volume'], spec['contract_size'], mid)
            gross += value
            sign = 1 if tr['side'] == 'LONG' else -1
            base, counter = tr['symbol'][:3], tr['symbol'][3:]
            currency[base] = currency.get(base, 0.) + sign * value
            currency[counter] = currency.get(counter, 0.) - sign * value
        return dict(n_open=len(positions), planned_open_risk_usd=risk,
                    margin_used_usd=gross/config['assumed_leverage'], gross_exposure_usd=gross,
                    stale_quote_positions=stale, **{f'exposure_{k}_usd': v for k, v in currency.items()})

    def mark(time, phase, value, adverse=None, favorable=None):
        nonlocal peak
        peak = max(peak, value)
        e = exposures(time, at_close=phase == 'bar_close')
        equity.append(dict(time=int(time), phase=phase, balance_usd=balance, equity_close_usd=value,
            equity_adverse_usd=value if adverse is None else min(adverse, value),
            equity_favorable_usd=value if favorable is None else max(favorable, value),
            **e))

    mark(start, 'initial', initial)
    for time in sorted(timeline):
        # Settle all marks of the same phase together; no strategy gets to spend
        # another strategy's not-yet-observed favorable intrabar movement.
        for source_phase, output_phase in [('bar_envelope', 'bar_close'), ('exit_at_open', 'gap_open')]:
            due = [(cid, p, p['marks'].get((time, source_phase))) for cid, p in positions.items()]
            if not any(m is not None for _, _, m in due):
                continue
            close_total = adverse_total = favorable_total = 0.
            closing = []
            before = balance
            for cid, position, m in due:
                if m is not None:
                    position['last_pnl'] = float(m['pnl_close_usd'])
                    close_total += float(m['pnl_close_usd'])
                    adverse_total += float(m['pnl_adverse_usd'])
                    favorable_total += float(m['pnl_favorable_usd'])
                    tr = position['trade']
                    if tr['status'] == 'closed' and int(tr['exit_time']) == time:
                        expected_phase = 'exit_at_open' if str(tr['exit_reason']).endswith('_gap_open') else 'bar_envelope'
                        if source_phase == expected_phase:
                            closing.append(cid)
                else:
                    close_total += position['last_pnl']
                    adverse_total += position['last_pnl']
                    favorable_total += position['last_pnl']
            for cid in closing:
                position = positions.pop(cid)
                tr = position['trade']
                balance += tr['net_pnl_before_unknown_swap_usd']
                tr['exit_shared_balance_usd'] = balance
                trades.append(tr)
                position['event']['status'] = 'executed'
            mark(time, output_phase, before + close_total, before + adverse_total, before + favorable_total)
        # A future censor flag is consumed only when the missing-data event is
        # observed. Until then the position remains open and occupies capacity.
        censored = [p for p in positions.values() if p['censor_time'] is not None and time >= p['censor_time']]
        if censored:
            complete, censor_time = False, int(time)
            censor_reason = ';'.join(sorted({p['trade']['status'] for p in censored}))
            break
        if time >= end:
            break
        # Lack of a current open during the declared source weekday is itself
        # observable. Do not admit orders using a stale valuation while waiting
        # for a future bar to confirm the exact missing interval.
        if positions and pd.Timestamp(time, unit='s', tz='UTC').dayofweek < 5:
            if any(quote(p['trade']['symbol'], time)[3] for p in positions.values()):
                complete, censor_time, censor_reason = False, int(time), 'missing_current_open_for_live_position'
                break
        if not positions and time not in scheduled:
            continue
        current = balance + sum(floating(p, time) for p in positions.values())
        mark(time, 'pre_entry', current)
        if day != time // 86400:
            day, day_start = time // 86400, current
        peak_halted |= current <= peak * (1-config['peak_entry_halt_fraction'])
        daily_halted = current <= day_start * (1-config['daily_entry_halt_fraction'])
        for candidate, event in sorted(scheduled.get(time, []), key=lambda x: (order[x[0]['cell_id']], x[0]['candidate_id'])):
            cell, symbol = candidate['cell_id'], candidate['symbol']
            current = balance + sum(floating(p, time) for p in positions.values())
            peak_halted |= current <= peak * (1-config['peak_entry_halt_fraction'])
            daily_halted = current <= day_start * (1-config['daily_entry_halt_fraction'])
            event.update(shared_equity_before_usd=current, shared_balance_before_usd=balance,
                         target_risk_usd=current * config['risk_fraction'])
            current_positions = [p['trade'] for p in positions.values()]
            reason = ''
            if peak_halted or daily_halted:
                reason = 'skipped_peak_entry_halt' if peak_halted else 'skipped_daily_entry_halt'
            elif any(p['cell_id'] == cell for p in current_positions):
                reason = 'skipped_rule_overlap'
            elif len(positions) >= config['max_positions']:
                reason = 'skipped_position_cap'
            elif mode == 'block_opposite' and any(p['symbol'] == symbol and p['side'] != candidate['side'] for p in current_positions):
                reason = 'skipped_opposite_position'
            if reason:
                event['status'] = reason
                continue
            path = trade_path(bars[symbol], candidate, specs[symbol], execution, current,
                              risk_fraction=config['risk_fraction'], scenario=scenario)
            tr = path['trade']
            if tr is None:
                event['status'] = path['events'][0]['status']
                continue
            # Only immutable entry fields are used below; status/exit/PnL and
            # future marks do not participate in admission or sizing.
            tr.update(cell_id=cell, shared_entry_equity_usd=current, mode=mode)
            own_risk = tr['planned_risk_usd']
            existing_risk = sum(p['planned_risk_usd'] for p in current_positions)
            symbol_risk = sum(p['planned_risk_usd'] for p in current_positions if p['symbol'] == symbol)
            _, _, mid, _ = quote(symbol, time)
            margin = notional_usd(symbol, tr['volume'], specs[symbol]['contract_size'], mid) / config['assumed_leverage']
            existing_margin = exposures(time)['margin_used_usd']
            entry_mark = path['marks'].loc[path['marks'].phase.eq('entry_liquidation')].iloc[0]
            if existing_risk + own_risk > current * config['max_open_risk_fraction'] + 1e-8:
                reason = 'skipped_portfolio_risk_cap'
            elif symbol_risk + own_risk > current * config['max_symbol_risk_fraction'] + 1e-8:
                reason = 'skipped_symbol_risk_cap'
            elif existing_margin + margin > current + float(entry_mark.pnl_close_usd) + 1e-8:
                reason = 'skipped_assumed_margin'
            if reason:
                event['status'] = reason
                continue
            event.update(status='open', volume=tr['volume'], planned_risk_usd=own_risk,
                         margin_at_entry_usd=margin)
            marks = {(int(m['time']), m['phase']): m for m in path['marks'].to_dict('records') if m['phase'] != 'entry_liquidation'}
            stop_time = None
            if tr['status'] != 'closed':
                stop_time = int(tr['censor_gap_end']) if tr['status'] == 'censored_time_gap' else int(tr['last_observed_time'])
            positions[candidate['candidate_id']] = dict(trade=tr, event=event, marks=marks,
                last_pnl=float(entry_mark.pnl_close_usd), censor_time=stop_time)
            mark(time, 'post_entry', current + float(entry_mark.pnl_close_usd))
    if positions:
        complete = False
        censor_reason = censor_reason or 'positions_unresolved_at_end'
        for p in positions.values():
            p['event']['status'] = p['trade']['status'] if p['trade']['status'] != 'closed' else 'censored_shared_account'
            # Never publish the future final PnL of another still-open position
            # after the shared account has stopped at a missing-data event.
            tr = p['trade'].copy()
            for key in ['exit_time', 'exit_time_lower', 'exit_time_upper', 'exit_index', 'exit_fill',
                        'net_pnl_before_unknown_swap_usd', 'net_pnl_usd', 'result_r', 'exit_equity_usd']:
                tr[key] = np.nan
            tr.update(status=p['event']['status'], last_observed_time=min(int(time), int(tr['last_observed_time'])))
            trades.append(tr)
    for event in event_rows:
        if event['status'] == 'pending':
            event['status'] = 'skipped_account_censored'
    if complete:
        mark(end, 'bar_close', balance)
    trade_frame = pd.DataFrame(trades) if trades else pd.DataFrame(columns=[
        'candidate_id', 'cell_id', 'symbol', 'side', 'status', 'entry_time', 'exit_time', 'exit_reason',
        'net_pnl_before_unknown_swap_usd', 'result_r', 'volume'])
    return dict(trades=trade_frame, events=pd.DataFrame(event_rows), equity=pd.DataFrame(equity),
                complete=complete, censor_reason=censor_reason, censor_time=censor_time)
