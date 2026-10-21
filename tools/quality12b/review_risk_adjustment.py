"""Descriptive closure of a completed, frozen OFF/ON risk-adjustment batch.

No optimization, tester launch, or modification of frozen run artifacts.
"""
import argparse
import csv
import hashlib
import json
from collections import Counter
from decimal import Decimal
from pathlib import Path


def read(path, delimiter=','):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f, delimiter=delimiter))


def write(path, rows):
    assert rows, path
    with path.open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def money(row):
    return Decimal(row['net'])


def run(batch):
    assert json.loads((batch / 'status.json').read_text(encoding='utf-8-sig'))['status'] == 'COMPLETED'
    review = batch / 'review'
    review.mkdir(exist_ok=True)
    sources, monthly, utilization, changes, adjustments = [], [], [], [], []
    for symbol in ['USDJPY', 'EURUSD', 'XAUUSD']:
        variants = {}
        for mode in ['legacy', 'off', 'on']:
            folder = batch / f'{symbol}_{mode}'
            audit = json.loads((folder / 'audit.json').read_text(encoding='utf-8-sig'))
            assert audit['passed']
            sources.extend(folder / n for n in ['audit.json', 'trades.csv', 'risk.csv', 'funnel.csv'])
            trades = read(folder / 'trades.csv')
            assert len(trades) == audit['actual']['n']
            assert abs(sum(map(money, trades)) - Decimal(str(audit['actual']['net']))) < Decimal('0.00001')
            indexed = {t['entry_time']: t for t in trades}
            assert len(indexed) == len(trades), 'Unexpected multiple entries at the same time'
            variants[mode] = indexed
            counts = Counter(t['entry_time'][:7] for t in trades)
            for month in ['2023-01', '2023-02', '2023-03']:
                monthly.append(dict(symbol=symbol, mode=mode, month=month, entries=counts[month]))
            plans = [r for r in read(folder / 'risk.csv', ';') if r['reason'] == 'OK']
            assert len(plans) == len(trades)
            ratios = [Decimal(r['planned_loss']) / Decimal(r['budget']) for r in plans]
            assert all(0 < x <= 1 for x in ratios)
            utilization.append(dict(symbol=symbol, mode=mode, n=len(ratios),
                                    minimum=min(ratios), mean=sum(ratios)/len(ratios), maximum=max(ratios)))
        assert variants['legacy'] == variants['off'], 'Legacy/OFF trade-table parity failed'
        off, on = variants['off'], variants['on']
        off_only, on_only = sorted(off.keys() - on.keys()), sorted(on.keys() - off.keys())
        assert len(off_only) == len(on_only), 'This review expects substitutions; inspect unmatched entries'
        symbol_changes = []
        def add(kind, a, b, gate_reason=''):
            symbol_changes.append(dict(symbol=symbol, change=kind, off_entry=a['entry_time'], on_entry=b['entry_time'],
                off_exit=a['exit_time'], on_exit=b['exit_time'], off_volume=a['volume'], on_volume=b['volume'],
                off_net=a['net'], on_net=b['net'], delta_usd=money(b)-money(a), on_later_gate_reason=gate_reason))
        funnel = {r['time'].replace('.', '-'): r for r in read(batch / f'{symbol}_on/funnel.csv', ';')}
        for old, new in zip(off_only, on_only):
            assert old[:10] == new[:10] and new < old, 'Review timing association manually'
            gate = funnel[old]
            assert gate['signal'] == 'true' and gate['spread_allowed'] == 'true' and gate['entry_gate'] == 'false'
            reasons = []
            if int(gate['positions']) > 0:
                reasons.append('POSITION_OPEN')
            if int(gate['daily_entries']) >= 2:
                reasons.append('DAILY_ENTRY_LIMIT_2')
            assert reasons and gate['daily_cap'] == 'false' and gate['equity_cap'] == 'false'
            add('EARLIER_ENTRY_SUBSTITUTION', off[old], on[new], '|'.join(reasons))
        for time in sorted(off.keys() & on.keys()):
            a, b = off[time], on[time]
            if money(a) != money(b) or a['volume'] != b['volume']:
                assert all(a[k] == b[k] for k in ['entry_price', 'exit_time', 'exit_price', 'initial_sl'])
                add('SAME_TRADE_EQUITY_VOLUME_EFFECT', a, b)
        delta = sum(map(money, on.values())) - sum(map(money, off.values()))
        assert sum((c['delta_usd'] for c in symbol_changes), Decimal(0)) == delta
        changes.extend(symbol_changes)
        recovered_path = batch / f'{symbol}_on/recovered_plans.json'
        sources.append(recovered_path)
        recovered = json.loads(recovered_path.read_text(encoding='utf-8-sig'))
        for plan in recovered:
            time = plan['time'].replace('.', '-')
            t = on[time]
            assert Decimal(t['volume']) == Decimal(plan['after_volume'])
            adjustments.append(dict(symbol=symbol, time=time, before_volume=plan['before_volume'],
                after_volume=plan['after_volume'], before_loss=plan['before_loss'], after_loss=plan['after_loss'],
                budget=plan['budget'], checks=plan['checks'], same_entry_in_off=time in off,
                actual_net=t['net'], actual_exit=t['exit_time']))
    audits = list(batch.glob('*/audit.json'))
    assert len(audits) == 12 and all(json.loads(p.read_text(encoding='utf-8-sig'))['passed'] for p in audits)
    sources.extend(audits)
    write(review / 'monthly_entries.csv', monthly)
    write(review / 'planned_risk_utilization.csv', utilization)
    write(review / 'trade_difference_ledger.csv', changes)
    write(review / 'recovered_plan_ledger.csv', adjustments)
    subtotals = {kind: str(sum((c['delta_usd'] for c in changes if c['change'] == kind), Decimal(0)))
                for kind in sorted({c['change'] for c in changes})}
    evidence = dict(passed=True, completed_audits=len(audits), recovered_plans=len(adjustments),
        delta_subtotals_usd=subtotals, total_delta_usd=str(sum((c['delta_usd'] for c in changes), Decimal(0))),
        source_sha256={str(p.relative_to(batch)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(sources))})
    (review / 'review_checks.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in evidence.items() if k != 'source_sha256'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('batch', type=Path)
    run(parser.parse_args().batch.resolve())
