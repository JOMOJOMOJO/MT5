"""Compare fixed-period candidates and independently scan native M1 closes."""
import csv
import json
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'reports/qa/three_wave'
OUT = ROOT / 'early_wave_fix'


def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def dt(s):
    return datetime.strptime(s, '%Y.%m.%d %H:%M:%S')


def main():
    before = rows(ROOT / 'april_real_ticks/TW_signals.csv')
    after = rows(ROOT / 'early_april_final/TW_signals.csv')
    rates = rows(OUT / 'TW_april_rates.csv')
    closes = [(dt(r['time']) + timedelta(minutes=1), float(r['close'])) for r in rates]
    old = {r['signal_id']: r for r in before}
    new = {r['signal_id']: r for r in after}
    records, issues = [], []
    for key, r in old.items():
        # Scan from the point the fixed parent high became available.
        start, signal = dt(r['m5_wave1_confirmed']), dt(r['signal_time'])
        threshold = float(r['m5_wave1_high'])
        first = next((t for t, price in closes if start <= t < signal and price > threshold), None)
        kept = key in new
        if kept == bool(first):
            issues.append('candidate/cutoff mismatch: ' + key)
        records.append(dict(signal_time=r['signal_time'], signal_id=key, retained=kept,
                            m5_choch=r['m5_choch_time'], m5_wave1_high=threshold,
                            m5_high_confirmed=r['m5_wave1_confirmed'],
                            first_prior_m5_break=first.strftime('%Y.%m.%d %H:%M:%S') if first else '',
                            m1_choch=r['m1_choch_time'], m1_hl_confirmed=r['m1_wave2_confirmed']))
    if set(new) - set(old):
        issues.append('unexpected added candidates')
    funnels = {}
    for name in ('april_real_ticks', 'early_april_final'):
        events, setups = defaultdict(set), defaultdict(set)
        for row in rows(ROOT / name / 'TW_transitions.csv'):
            events[row['reason']].add((row['setup'], row['time']))
            setups[row['reason']].add(row['setup'])
        funnels[name] = {reason: {'events': len(value), 'distinct_m5_setups': len(setups[reason])}
                         for reason, value in events.items()}
    with (OUT / 'candidate_comparison.csv').open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)
    result = dict(before=len(old), after=len(new), removed=len(set(old)-set(new)),
                  added=len(set(new)-set(old)), issues=issues, funnels=funnels)
    (OUT / 'comparison.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))
    if issues:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
