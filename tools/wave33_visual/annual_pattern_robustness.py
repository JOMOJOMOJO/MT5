"""Four fixed, descriptive annual contrasts; no EA edits or tester execution."""
from __future__ import annotations

import argparse
from bisect import bisect_right
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path

import numpy as np


def load_csv(path, delimiter=','):
    with path.open(encoding='utf-8-sig', newline='') as f:
        yield from csv.DictReader(f, delimiter=delimiter)


def stamp(value):
    return datetime.fromisoformat(value.replace('.', '-'))


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for data in iter(lambda: f.read(1024 * 1024), b''):
            h.update(data)
    return h.hexdigest()


def write_csv(path, rows):
    if rows:
        with path.open('w', encoding='utf-8-sig', newline='') as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)


def metrics(rows):
    r = np.array([float(t['net_r']) for t in rows])
    cash = np.array([float(t['net_cash']) for t in rows])
    return dict(n=len(r), wins=int(sum(r > 0)), losses=int(sum(r < 0)),
                win_rate=float(np.mean(r > 0)) if len(r) else None,
                mean_r=float(np.mean(r)) if len(r) else None,
                sum_r=float(sum(r)), net_cash=float(sum(cash)),
                pf_cash=float(sum(cash[cash > 0])/-sum(cash[cash < 0])) if any(cash < 0) else None)


def upper_context(path):
    known, highs, lows, closes = [], [], [], []
    for row in load_csv(path, ';'):
        known.append(stamp(row['known_at']))
        highs.append(float(row['high']))
        lows.append(float(row['low']))
        closes.append(float(row['close']))
    assert all(a <= b for a, b in zip(known, known[1:]))
    # Independent implementation: direct window means rather than convolution.
    tr = [max(h-l, abs(h-(closes[i-1] if i else closes[i])),
                        abs(l-(closes[i-1] if i else closes[i])))
          for i, (h, l) in enumerate(zip(highs, lows))]
    mean14 = [None] * 13 + [sum(tr[i-13:i+1])/14 for i in range(13, len(tr))]

    def at(time):
        i = bisect_right(known, time)-1
        assert i >= 113
        return known[i], mean14[i], mean14[i] / (sum(mean14[i-100:i])/100)
    return at


def bootstrap(rows, feature, positive, negative, rng, reps):
    # One resampling family only: complete entry-month clusters, paired across groups.
    months = [f'2020-{i:02d}' for i in range(1, 13)]
    sums = np.zeros((12, 2))
    counts = np.zeros((12, 2))
    for i, month in enumerate(months):
        for j, value in enumerate((positive, negative)):
            selected = [float(t['net_r']) for t in rows if t['month'] == month and t[feature] == value]
            sums[i, j] = sum(selected)
            counts[i, j] = len(selected)
    samples = rng.integers(0, 12, size=(reps, 12))
    totals = sums[samples].sum(axis=1)
    ns = counts[samples].sum(axis=1)
    valid = (ns[:, 0] > 0) & (ns[:, 1] > 0)
    diffs = totals[valid, 0]/ns[valid, 0] - totals[valid, 1]/ns[valid, 1]
    lo, hi = np.quantile(diffs, [.00625, .99375])
    return dict(method='entry_month_cluster_bootstrap', repetitions=reps,
                valid_repetitions=int(sum(valid)), months=12, interval_level=.9875,
                family_size=4, lower=float(lo), upper=float(hi))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--annual', type=Path, default=Path('reports/backtest/runs/wave33_v170_2020'))
    ap.add_argument('--out', type=Path, default=Path('reports/backtest/runs/wave33_v170_2020/pattern_review_20261023/robustness'))
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    assert (args.out/'definition.md').exists(), 'Save definition before executing analysis'
    batch = args.annual/'20261022_161002_0ef87d9b'
    original = json.loads((args.annual/'analysis/streak_summary.json').read_text(encoding='utf-8-sig'))
    validation = json.loads((args.annual/'analysis/analysis_validation.json').read_text(encoding='utf-8-sig'))
    assert validation['status'] == 'PASS' and validation['trade_count'] == 475
    hashes = {}
    for rel, expected in original['source_sha256'].items():
        path = batch/rel.replace('\\', '/')
        actual = digest(path)
        assert actual.lower() == expected.lower(), f'Source changed: {rel}'
        hashes[rel] = actual
    trades = list(load_csv(args.annual/'analysis/trades.csv'))
    assert len(trades) == 475
    assert len({(t['arm'], t['setup_id']) for t in trades}) == len(trades)
    audit_counts, signal_context_differences = {}, []
    for arm, folder in [('A', 'a_extension_on'), ('B', 'b_extension_on')]:
        wanted = {t['setup_id']: t for t in trades if t['arm'] == arm}
        fills, exits, signals = {}, {}, {}
        for row in load_csv(batch/folder/'events.csv', ';'):
            if row['setup_id'] not in wanted:
                continue
            if row['event_type'] == 'FILL':
                assert row['setup_id'] not in fills
                fills[row['setup_id']] = row
            elif row['event_type'] == 'EXIT':
                assert row['setup_id'] not in exits
                exits[row['setup_id']] = row
            elif row['event_type'] == 'SIGNAL':
                signals[row['setup_id']] = row
        assert set(fills) == set(exits) == set(wanted)
        context = upper_context(batch/folder/'upper_bars.csv')
        for setup, t in wanted.items():
            fill, close, signal = fills[setup], exits[setup], signals[setup]
            entry = stamp(t['entry_at'])
            assert entry == stamp(fill['fill_at'])
            assert stamp(t['exit_at']) == stamp(close['exit_at'])
            assert t['direction'] == fill['direction']
            assert t['lower_recognition'] == fill['lower_recognition'] == signal['lower_recognition']
            cash, risk, r = (float(close[x]) for x in ('execution_net_cash', 'execution_initial_risk_money', 'realized_r'))
            assert abs(cash-float(t['net_cash'])) < 1e-9 and risk > 0
            assert abs(risk-float(t['risk_cash'])) < 1e-9
            assert abs(cash/risk-float(t['net_r'])) < 1e-12 and abs(r-cash/risk) < 1e-6
            assert t['outcome'] == ('WIN' if cash > 0 else 'LOSS' if cash < 0 else 'FLAT')
            known, mean14, ratio = context(entry)
            assert known == stamp(t['upper_bar_known_at']) and known <= entry
            assert abs(mean14-float(t['upper_tr_mean14'])) < 1e-9
            assert abs(ratio-float(t['volatility_ratio'])) < 1e-9
            assert t['volatility_regime'] == ('EXPANDING' if ratio >= 1 else 'CONTRACTING')
            signal_at = stamp(signal['signal_known_at'])
            signal_known, _, signal_ratio = context(signal_at)
            if known != signal_known or abs(ratio-signal_ratio) > 1e-9:
                signal_context_differences.append(dict(arm=arm, setup_id=setup,
                    signal_at=signal_at.isoformat(' '), entry_at=entry.isoformat(' ')))
        audit_counts[arm] = dict(n=len(wanted), reconciliation='FILL/EXIT, direction, recognition, cash, risk, R, outcome, as-of upper context',
                                 net_cash=sum(float(t['net_cash']) for t in wanted.values()),
                                 sum_r=sum(float(t['net_r']) for t in wanted.values()))
    assert not signal_context_differences, 'FILL context not yet known at SIGNAL; inspect before filtering'

    periods = [('YEAR', lambda t: True), ('H1', lambda t: t['month'] <= '2020-06'),
               ('H2', lambda t: t['month'] >= '2020-07')]
    periods += [(f'Q{q}', lambda t, q=q: (int(t['month'][-2:])-1)//3+1 == q) for q in range(1, 5)]
    definitions = [('volatility', 'volatility_regime', 'EXPANDING', 'CONTRACTING'),
                   ('recognition', 'lower_recognition', 'NORMALIZED_COUNTERTREND', 'SIMPLE_REACTION_BREAK')]
    groups, contrasts, intervals, directions, baselines = [], [], [], [], []
    rng = np.random.default_rng(20261023)
    for arm in ('A', 'B'):
        rows = [t for t in trades if t['arm'] == arm]
        assert set(t['lower_recognition'] for t in rows) == {'NORMALIZED_COUNTERTREND', 'SIMPLE_REACTION_BREAK'}
        for direction in ('LONG', 'SHORT'):
            directions.append(dict(arm=arm, direction=direction,
                                   **metrics([t for t in rows if t['direction'] == direction])))
        for period, accept in periods:
            current = [t for t in rows if accept(t)]
            baselines.append(dict(arm=arm, period=period, **metrics(current)))
            for name, feature, positive, negative in definitions:
                current_groups = []
                for value in (positive, negative):
                    m = metrics([t for t in current if t[feature] == value])
                    groups.append(dict(arm=arm, period=period, hypothesis=name, group=value, **m))
                    current_groups.append(m)
                a, b = current_groups
                diff = a['mean_r']-b['mean_r'] if a['n'] and b['n'] else None
                contrasts.append(dict(arm=arm, period=period, hypothesis=name,
                                      positive_group=positive, negative_group=negative,
                                      positive_n=a['n'], negative_n=b['n'], difference_mean_r=diff))
                if period == 'YEAR':
                    intervals.append(dict(arm=arm, hypothesis=name, estimate=diff,
                        **bootstrap(rows, feature, positive, negative, rng, 20000)))
    write_csv(args.out/'groups.csv', groups)
    write_csv(args.out/'contrasts.csv', contrasts)
    write_csv(args.out/'baseline_periods.csv', baselines)
    write_csv(args.out/'directions_annual.csv', directions)
    write_csv(args.out/'bootstrap_intervals.csv', intervals)
    validation = dict(status='PASS', input_trade_count=475, original_integrity_checks=6719,
                      source_sha256=hashes, trades_sha256=digest(args.annual/'analysis/trades.csv'),
                      definition_sha256=digest(args.out/'definition.md'), script_sha256=digest(Path(__file__)),
                      per_arm=audit_counts, signal_context_difference_count=0,
                      no_new_test_or_ea_changes=True, main_comparisons=4,
                      period_split_is_oos=False, resampling_seed=20261023)
    (args.out/'validation.json').write_text(json.dumps(validation, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(status='PASS', contrasts=intervals, audit=audit_counts), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
