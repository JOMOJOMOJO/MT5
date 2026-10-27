"""Independent read-only Decimal and availability audit. Never launches MT5.

This file owns only analysis/math; frozen source data and all EA files stay intact.
The native records contain the actual 13-close query at each decision. The proxy
is independently rebuilt from timestamped M5 records, requiring 12 exact slots.
"""
from __future__ import annotations

import csv
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 50
OUT = Path(__file__).resolve().parent
BATCH = OUT.parents[1]
REPO = next(p for p in OUT.parents if (p / 'mql').is_dir())
DT = '%Y.%m.%d %H:%M:%S'
EPS = Decimal('1e-12')
LIMIT = Decimal('.25')
TICK = Decimal('.01')


def parse(value):
    return datetime.strptime(value, DT)


def stamp(value):
    return value.strftime(DT)


def read(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.reader(stream, delimiter=';')
        header = next(reader)
        result = []
        for line, fields in enumerate(reader, 2):
            assert len(fields) == len(header), (path.name, line, len(fields), len(header))
            result.append(dict(zip(header, fields)))
        return result


def write(name, rows):
    if not rows:
        return
    fields = list(dict.fromkeys(k for row in rows for k in row))
    with (OUT / name).open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def ratio(prices):
    net = abs(prices[-1] - prices[0])
    path = sum((abs(b - a) for a, b in zip(prices, prices[1:])), Decimal(0))
    return net, path, net / path if path else None


def source(arm, suffix):
    paths = list((BATCH / arm / 'source').glob('*' + suffix))
    assert len(paths) == 1
    return paths[0]


def complete_proxy(rows):
    groups = defaultdict(list)
    previous = None
    for row in rows:
        start, end, known = map(parse, (row['bar_time'], row['closed_at'], row['known_at']))
        assert previous is None or start > previous
        assert end == start + timedelta(minutes=5) and known >= end
        assert start.minute % 5 == 0 and start.second == 0
        previous = start
        groups[start.replace(minute=0, second=0)].append((start, end, known, Decimal(row['close'])))
    complete, partial = [], []
    for start, members in sorted(groups.items()):
        if [m[0] for m in members] != [start + timedelta(minutes=5*i) for i in range(12)]:
            partial.append(dict(start=stamp(start), present_m5=len(members),
                                first_m5=stamp(members[0][0]), last_m5=stamp(members[-1][0]),
                                max_known=stamp(max(m[2] for m in members))))
            continue
        complete.append(dict(start=start, end=start + timedelta(hours=1),
                             known=max(m[2] for m in members), price=members[-1][3]))
    return complete, partial


audit_rows, proxy_rows, test_rows, all_native_points = [], [], [], defaultdict(list)
arms = {}
hashes = {}
max_error = Decimal(0)
for arm in ('off', 'on'):
    native_path = source(arm, '_h1_efficiency.csv')
    bar_path = source(arm, '_upper_bars.csv')
    rows, bars = read(native_path), read(bar_path)
    arms[arm] = rows
    hashes[arm] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (native_path, bar_path)}
    proxy, partial = complete_proxy(bars)
    write(f'{arm}_incomplete_proxy_hours.csv', partial)
    for row in rows:
        times = list(map(parse, row['bar_open_times'].split('|')))
        prices = list(map(Decimal, row['closes'].split('|')))
        cutoff = parse(row['decision_at'])
        assert row['symbol'] == 'XAUUSD+'
        assert row['enabled'] == str(arm == 'on').lower()
        assert row['valid'] == 'true' and row['reason'] == 'OK'
        assert len(times) == len(prices) == int(row['close_count']) == 13
        assert all(b > a for a, b in zip(times, times[1:]))
        assert all(t.minute == t.second == 0 for t in times)
        assert all(t + timedelta(hours=1) <= cutoff for t in times)
        assert all(p.is_finite() and p > 0 for p in prices)
        assert stamp(times[0]) == row['first_open'] and stamp(times[-1]) == row['last_open']
        assert stamp(times[-1] + timedelta(hours=1)) == row['last_close']
        span = int((times[-1] - times[0]).total_seconds())
        gaps = [int((b-a).total_seconds()) for a, b in zip(times, times[1:]) if b-a > timedelta(hours=1)]
        assert span == int(row['span_seconds']) and len(gaps) == int(row['gap_count'])
        net, path, er = ratio(prices)
        assert er is not None and 0 <= er <= 1
        errors = {key: abs(Decimal(row[key]) - value) for key, value in (
            ('net_distance', net), ('path_distance', path), ('er', er), ('roundtrip', 1-er))}
        assert all(value <= EPS for value in errors.values()), (arm, cutoff, errors)
        max_error = max(max_error, *errors.values())
        exact_low, eps_low = er <= LIMIT, er <= LIMIT + EPS
        tick_net, tick_path, tick_er = ratio([p.quantize(TICK) for p in prices])
        assert tick_er is not None
        assert exact_low == eps_low == (tick_er <= LIMIT)
        expected = 'ALLOW'
        if arm == 'on' and eps_low:
            expected = 'SKIP' if row['precedence'] == 'ELIGIBLE' else 'WOULD_SKIP_PRECEDENCE'
        assert row['outcome'] == expected
        age = int((cutoff - times[-1] - timedelta(hours=1)).total_seconds())
        audit_rows.append(dict(arm=arm, setup_id=row['setup_id'], decision_at=row['decision_at'],
            er=row['er'], decimal_er=str(er), tick_rounded_er=str(tick_er), roundtrip=row['roundtrip'],
            low_er=exact_low, outcome=row['outcome'], precedence=row['precedence'],
            first_open=row['first_open'], last_open=row['last_open'],
            span_hours=span/3600, gap_count=len(gaps), max_gap_hours=max(gaps, default=3600)/3600,
            last_close_age_seconds=age, nearest_threshold_distance=str(abs(er-LIMIT)),
            max_numeric_error=str(max(errors.values())),
            native_13_closes=row['closes'], native_13_opens=row['bar_open_times']))
        for time, price in zip(times, prices):
            all_native_points[time].append((arm, cutoff, price))
        available = [b for b in proxy if b['end'] <= cutoff and b['known'] <= cutoff]
        comparison = dict(arm=arm, decision_at=row['decision_at'], setup_id=row['setup_id'],
                          native_er=str(er), native_low=exact_low,
                          proxy_available_h1=len(available), native_first_open=row['first_open'],
                          native_last_open=row['last_open'])
        if len(available) < 13:
            comparison.update(status='PROXY_UNAVAILABLE_STARTUP', windows_equal=False,
                              proxy_er='', proxy_low='', proxy_first_open='', proxy_last_open='')
        else:
            win = available[-13:]
            _, _, proxy_er = ratio([b['price'] for b in win])
            assert proxy_er is not None
            times_equal = times == [b['start'] for b in win]
            closes_equal = [p.quantize(TICK) for p in prices] == [b['price'] for b in win]
            comparison.update(status='EQUAL' if times_equal and closes_equal else 'DIFFERENT',
                windows_equal=times_equal and closes_equal,
                max_price_difference=str(max(abs(p-b['price']) for p,b in zip(prices,win))) if times_equal else '',
                proxy_er=str(proxy_er), proxy_low=proxy_er <= LIMIT,
                proxy_first_open=stamp(win[0]['start']), proxy_last_open=stamp(win[-1]['start']),
                proxy_max_known_at=stamp(max(b['known'] for b in win)),
                absolute_er_difference=str(abs(proxy_er-er)))
        proxy_rows.append(comparison)
    tests_path = source(arm, '_h1efficiency_policy_tests.csv')
    with tests_path.open(encoding='utf-8-sig', newline='') as stream:
        tests = list(csv.reader(stream, delimiter=';'))
    assert tests[-1] == ['SUMMARY', 'PASS', '45', '0']
    assert len(tests) == 46 and all(t[1] == 'PASS' for t in tests[:-1])
    test_rows.extend(dict(arm=arm, test=t[0], status=t[1]) for t in tests[:-1])

# Paired decision equality is established by actual IDs and timestamps; no blind
# row-index comparison, since filters can alter candidate availability in general.
paired = []
key = lambda r: (r['setup_id'], r['decision_at'])
off = {key(r): r for r in arms['off']}
on = {key(r): r for r in arms['on']}
assert len(off) == len(arms['off']) and len(on) == len(arms['on'])
assert off.keys() == on.keys()
excluded_fields = {'enabled', 'outcome'}
for identity, left in off.items():
    right = on[identity]
    differences = [f for f in left if f not in excluded_fields and left[f] != right[f]]
    assert not differences, (identity, differences)
    paired.append(dict(setup_id=identity[0], decision_at=identity[1],
                       identical_query_and_math=True, off_outcome=left['outcome'], on_outcome=right['outcome']))

# The same native H1 bar must not acquire a different historical close when it
# appears again in an overlapping window or the other arm.
native_points = []
for time, observations in sorted(all_native_points.items()):
    values = {p for _, _, p in observations}
    assert len(values) == 1
    native_points.append(dict(h1_open=stamp(time), close=str(next(iter(values))),
        occurrences=len(observations), earliest_query=stamp(min(d for _,d,_ in observations)),
        latest_query=stamp(max(d for _,d,_ in observations))))

# Non-performance arithmetic fixtures independently exercise the definition.
fixtures = [
    ('monotone_up', [Decimal(100+i) for i in range(13)], Decimal(1)),
    ('monotone_down', [Decimal(112-i) for i in range(13)], Decimal(1)),
    ('alternating', [Decimal(100+i%2) for i in range(13)], Decimal(0)),
    ('single_v_turn', list(map(Decimal, [100,101,102,103,104,105,106,105,104,103,102,101,100])), Decimal(0)),
    ('flat_is_undefined', [Decimal(100)]*13, None),
    ('exact_threshold', [Decimal(100+i) for i in range(10)]+
                        [Decimal(109)-Decimal('1.8')*i for i in range(1,4)], LIMIT),
]
fixture_rows=[]
for name,prices,expected in fixtures:
    _,_,actual=ratio(prices)
    assert actual==expected
    fixture_rows.append(dict(fixture=name, er='' if actual is None else str(actual),
                             expected='' if expected is None else str(expected), status='PASS'))

# Verify the old archived M5 snapshots and native-run M5 share unchanged closes
# on their common timestamps, while preserving the different collection extents.
native_m5 = {r['bar_time']: r for r in read(source('off','_upper_bars.csv'))}
old_m5_rows = []
for label in ('gold_v180','gold_v190'):
    old_path = REPO / 'reports/backtest/analysis/wave33_january_20261026/source' / label / 'upper_bars.csv'
    old = {r['bar_time']: r for r in read(old_path)}
    common = native_m5.keys() & old.keys()
    price_diffs = sum(any(Decimal(old[t][f]) != Decimal(native_m5[t][f])
                         for f in ('open','high','low','close')) for t in common)
    known_diffs = sum(old[t]['known_at'] != native_m5[t]['known_at'] for t in common)
    old_m5_rows.append(dict(old_source=label, old_m5_count=len(old), native_m5_count=len(native_m5),
                           common_m5_count=len(common), ohlc_difference_rows=price_diffs,
                           known_at_difference_rows=known_diffs))

summary = dict(
    metric_version='NATIVE_H1_CLOSED_ER12_025_V1',
    formula='ER=abs(C12-C0)/sum(i=1..12,abs(Ci-C(i-1))); roundtrip=1-ER',
    status='PASS_OBSERVED_WINDOWS_WITH_DECLARED_PARTIAL_HOUR_LIMITATION',
    input_window='13 observed closed H1 closes, 12 price differences; not 12 elapsed hours',
    rows_by_arm={a:len(r) for a,r in arms.items()},
    distinct_paired_decisions=len(paired), total_math_rows=len(audit_rows),
    runtime_policy_tests_per_arm=45, runtime_policy_tests_total=len(test_rows),
    max_decimal_numeric_error=str(max_error), formula_mismatches=0,
    causal_future_or_forming_rows=0, window_or_gap_metadata_mismatches=0,
    paired_window_or_er_mismatches=0, repeated_native_close_mismatches=0,
    decimal_threshold_classification_mismatches=0, tick_rounded_classification_mismatches=0,
    minimum_observed_distance_to_threshold=str(min(Decimal(r['nearest_threshold_distance']) for r in audit_rows)),
    unavailable_observations=0,
    missing_branch='No missing native decision occurred; handling is demonstrated by fixtures only, not market runtime.',
    outcome_counts={a:dict(Counter(r['outcome'] for r in rs)) for a,rs in arms.items()},
    unique_native_h1_closes_logged=len(native_points),
    independent_decimal_fixtures=len(fixture_rows),
    gap_windows_per_arm={a:sum(r['gap_count']!='0' for r in rs) for a,rs in arms.items()},
    span_hours_min=min(r['span_hours'] for r in audit_rows),
    span_hours_max=max(r['span_hours'] for r in audit_rows),
    last_close_age_seconds_max=max(r['last_close_age_seconds'] for r in audit_rows),
    proxy_status_counts_by_arm={a:dict(Counter(r['status'] for r in proxy_rows if r['arm']==a)) for a in arms},
    native_partial_jan20_hour_logged='2025.01.20 21:00:00' in {r['h1_open'] for r in native_points},
    partial_hour_parity='UNOBSERVABLE: Jan20 21:00 native H1 is absent from every logged decision window; no parity assertion.',
    startup_proxy='Native pre-start H1 exists; prospective M5 proxy lacks 13 complete closes at first query.',
    source_clock='broker/source time; UTC mapping is unverified',
    source_hashes=hashes)

write('decimal_all_rows.csv',audit_rows)
write('native_vs_complete_m5_proxy.csv',proxy_rows)
write('paired_decisions.csv',paired)
write('runtime_tests.csv',test_rows)
write('native_logged_h1_closes.csv',native_points)
write('old_archive_m5_overlap.csv',old_m5_rows)
write('independent_decimal_fixtures.csv',fixture_rows)
(OUT/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(summary,indent=2,ensure_ascii=False))
