"""Independent Decimal/availability audit of fixed Feb-Mar native H1 records.

Read only frozen source; write only this analysis/math directory. Never launch
MT5 or tune a threshold. Unlike January, unmatched decisions are not suppressed.
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
DT = '%Y.%m.%d %H:%M:%S'
EPS, LIMIT, TICK = Decimal('1e-12'), Decimal('.25'), Decimal('.01')


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
    path = sum((abs(b-a) for a,b in zip(prices,prices[1:])), Decimal(0))
    return net, path, net/path if path else None


def source(arm, suffix):
    paths = list((BATCH / arm / 'source').glob('*' + suffix))
    assert len(paths) == 1, (arm,suffix)
    return paths[0]


def complete_proxy(rows):
    groups = defaultdict(list)
    previous = None
    for row in rows:
        start,end,known = map(parse,(row['bar_time'],row['closed_at'],row['known_at']))
        assert previous is None or start > previous
        assert end == start+timedelta(minutes=5) and known >= end
        assert start.minute%5 == 0 and start.second == 0
        previous = start
        groups[start.replace(minute=0,second=0)].append((start,end,known,Decimal(row['close'])))
    complete,partial=[],[]
    for start,members in sorted(groups.items()):
        if [m[0] for m in members] != [start+timedelta(minutes=5*i) for i in range(12)]:
            partial.append(dict(start=stamp(start),present_m5=len(members),
                first_m5=stamp(members[0][0]),last_m5=stamp(members[-1][0]),
                max_known=stamp(max(m[2] for m in members))))
            continue
        complete.append(dict(start=start,end=start+timedelta(hours=1),
            known=max(m[2] for m in members),price=members[-1][3]))
    return complete,partial


arms,hashes={},{}
audit_rows,proxy_rows,test_rows=[],[],[]
all_native_points=defaultdict(list)
partial_hours_by_arm={}
max_error=Decimal(0)
for arm in ('off','on'):
    native_path,bar_path=source(arm,'_h1_efficiency.csv'),source(arm,'_upper_bars.csv')
    rows,bars=read(native_path),read(bar_path)
    arms[arm]=rows
    hashes[arm]={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (native_path,bar_path)}
    proxy,partial=complete_proxy(bars)
    partial_hours_by_arm[arm]=partial
    write(f'{arm}_incomplete_proxy_hours.csv',partial)
    # Last close of an observed partial-session H1 is still a legitimate native
    # H1 close. Keep it separate from the intentionally strict complete-M5 proxy.
    observed_m5_hours=defaultdict(list)
    for bar in bars:
        opened=parse(bar['bar_time']).replace(minute=0,second=0)
        observed_m5_hours[opened].append(bar)
    for row in rows:
        cutoff=parse(row['decision_at'])
        assert row['symbol']=='XAUUSD+'
        assert row['enabled']==str(arm=='on').lower()
        assert row['valid']=='true' and row['reason']=='OK'
        assert Decimal(row['threshold'])==LIMIT
        times=list(map(parse,row['bar_open_times'].split('|')))
        prices=list(map(Decimal,row['closes'].split('|')))
        assert len(times)==len(prices)==int(row['close_count'])==13
        assert all(b>a for a,b in zip(times,times[1:]))
        assert all(t.minute==t.second==0 for t in times)
        assert all(t+timedelta(hours=1)<=cutoff for t in times)
        assert all(p.is_finite() and p>0 for p in prices)
        assert stamp(times[0])==row['first_open'] and stamp(times[-1])==row['last_open']
        assert stamp(times[-1]+timedelta(hours=1))==row['last_close']
        span=int((times[-1]-times[0]).total_seconds())
        gaps=[int((b-a).total_seconds()) for a,b in zip(times,times[1:]) if b-a>timedelta(hours=1)]
        assert span==int(row['span_seconds']) and len(gaps)==int(row['gap_count'])
        net,path,er=ratio(prices)
        assert er is not None and 0<=er<=1
        errors={key:abs(Decimal(row[key])-value) for key,value in (
            ('net_distance',net),('path_distance',path),('er',er),('roundtrip',1-er))}
        assert all(e<=EPS for e in errors.values()),(arm,cutoff,errors)
        max_error=max(max_error,*errors.values())
        exact_low,eps_low=er<=LIMIT,er<=LIMIT+EPS
        _,_,tick_er=ratio([p.quantize(TICK) for p in prices])
        assert tick_er is not None
        assert exact_low==eps_low==(tick_er<=LIMIT)
        expected='ALLOW'
        if arm=='on' and eps_low:
            expected='SKIP' if row['precedence']=='ELIGIBLE' else 'WOULD_SKIP_PRECEDENCE'
        assert row['outcome']==expected,(arm,cutoff,row['outcome'],expected)
        age=int((cutoff-times[-1]-timedelta(hours=1)).total_seconds())
        audit_rows.append(dict(arm=arm,setup_id=row['setup_id'],decision_at=row['decision_at'],
            er=row['er'],decimal_er=str(er),tick_rounded_er=str(tick_er),roundtrip=row['roundtrip'],
            low_er=exact_low,outcome=row['outcome'],precedence=row['precedence'],
            first_open=row['first_open'],last_open=row['last_open'],span_hours=span/3600,
            gap_count=len(gaps),max_gap_hours=max(gaps,default=3600)/3600,
            last_close_age_seconds=age,nearest_threshold_distance=str(abs(er-LIMIT)),
            max_numeric_error=str(max(errors.values())),
            native_13_closes=row['closes'],native_13_opens=row['bar_open_times']))
        for time,price in zip(times,prices):
            all_native_points[time].append((arm,cutoff,price))
            if time in observed_m5_hours:
                members=observed_m5_hours[time]
                latest=max(members,key=lambda x:x['bar_time'])
                assert price.quantize(TICK)==Decimal(latest['close']), (arm,time,price,latest)
        available=[b for b in proxy if b['end']<=cutoff and b['known']<=cutoff]
        comparison=dict(arm=arm,decision_at=row['decision_at'],setup_id=row['setup_id'],
            native_er=str(er),native_low=exact_low,proxy_available_h1=len(available),
            native_first_open=row['first_open'],native_last_open=row['last_open'])
        if len(available)<13:
            comparison.update(status='PROXY_UNAVAILABLE_STARTUP',windows_equal=False,
                proxy_er='',proxy_low='',proxy_first_open='',proxy_last_open='')
        else:
            win=available[-13:]
            _,_,proxy_er=ratio([b['price'] for b in win])
            assert proxy_er is not None
            times_equal=times==[b['start'] for b in win]
            closes_equal=[p.quantize(TICK) for p in prices]==[b['price'] for b in win]
            comparison.update(status='EQUAL' if times_equal and closes_equal else 'DIFFERENT',
                windows_equal=times_equal and closes_equal,
                max_price_difference=str(max(abs(p-b['price']) for p,b in zip(prices,win))) if times_equal else '',
                proxy_er=str(proxy_er),proxy_low=proxy_er<=LIMIT,
                proxy_first_open=stamp(win[0]['start']),proxy_last_open=stamp(win[-1]['start']),
                proxy_max_known_at=stamp(max(b['known'] for b in win)),
                absolute_er_difference=str(abs(proxy_er-er)))
        proxy_rows.append(comparison)
    tests_path=source(arm,'_h1efficiency_policy_tests.csv')
    with tests_path.open(encoding='utf-8-sig',newline='') as stream:
        tests=list(csv.reader(stream,delimiter=';'))
    assert tests[-1]==['SUMMARY','PASS','45','0']
    assert len(tests)==46 and all(t[1]=='PASS' for t in tests[:-1])
    test_rows.extend(dict(arm=arm,test=t[0],status=t[1]) for t in tests[:-1])
    hashes[arm][tests_path.name]=hashlib.sha256(tests_path.read_bytes()).hexdigest()

# IDs/timestamps, rather than indices, preserve divergence caused by an entry
# filter freeing an active candidate/position lane. Audit all unmatched rows too.
key=lambda r:(r['setup_id'],r['decision_at'])
off={key(r):r for r in arms['off']}
on={key(r):r for r in arms['on']}
assert len(off)==len(arms['off']) and len(on)==len(arms['on'])
common=off.keys()&on.keys()
paired,unmatched=[],[]
query_fields=['symbol','direction','valid','reason','close_count','first_open','last_open',
    'last_close','span_seconds','gap_count','net_distance','path_distance','er','roundtrip',
    'threshold','bar_open_times','closes']
other_differences=[]
for identity in sorted(common):
    left,right=off[identity],on[identity]
    diffs=[f for f in query_fields if left[f]!=right[f]]
    assert not diffs,(identity,diffs)
    extras=[f for f in left if f not in set(query_fields)|{'enabled','outcome'} and left[f]!=right[f]]
    if extras:
        other_differences.append(dict(setup_id=identity[0],decision_at=identity[1],fields='|'.join(extras)))
    paired.append(dict(setup_id=identity[0],decision_at=identity[1],identical_query_and_math=True,
        off_outcome=left['outcome'],on_outcome=right['outcome'],other_differences='|'.join(extras)))
for arm,mapping,other in [('off',off,on),('on',on,off)]:
    for identity in sorted(mapping.keys()-other.keys()):
        row=mapping[identity]
        unmatched.append(dict(arm=arm,**row))

# A historical native H1 close must be stable in overlapping queries and arms.
native_points=[]
for time,observations in sorted(all_native_points.items()):
    values={p for _,_,p in observations}
    assert len(values)==1,(time,values)
    native_points.append(dict(h1_open=stamp(time),close=str(next(iter(values))),
        occurrences=len(observations),earliest_query=stamp(min(d for _,d,_ in observations)),
        latest_query=stamp(max(d for _,d,_ in observations))))

fixtures=[
    ('monotone_up',[Decimal(100+i) for i in range(13)],Decimal(1)),
    ('monotone_down',[Decimal(112-i) for i in range(13)],Decimal(1)),
    ('alternating',[Decimal(100+i%2) for i in range(13)],Decimal(0)),
    ('single_v_turn',list(map(Decimal,[100,101,102,103,104,105,106,105,104,103,102,101,100])),Decimal(0)),
    ('flat_is_undefined',[Decimal(100)]*13,None),
    ('exact_threshold',[Decimal(100+i) for i in range(10)]+
        [Decimal(109)-Decimal('1.8')*i for i in range(1,4)],LIMIT),
]
fixture_rows=[]
for name,prices,expected in fixtures:
    _,_,actual=ratio(prices)
    assert actual==expected
    fixture_rows.append(dict(fixture=name,er='' if actual is None else str(actual),
        expected='' if expected is None else str(expected),status='PASS'))

summary=dict(
    metric_version='NATIVE_H1_CLOSED_ER12_025_V1',
    formula='ER=abs(C12-C0)/sum(i=1..12,abs(Ci-C(i-1))); roundtrip=1-ER',
    status='PASS_OBSERVED_NATIVE_WINDOWS_WITH_DECLARED_PROXY_LIMITATION',
    input_window='13 observed closed H1 closes, 12 price differences; not 12 elapsed hours',
    rows_by_arm={a:len(r) for a,r in arms.items()},
    distinct_paired_decisions=len(paired),unmatched_decisions=unmatched,
    paired_other_field_differences=other_differences,
    total_math_rows=len(audit_rows),runtime_policy_tests_per_arm=45,
    runtime_policy_tests_total=len(test_rows),max_decimal_numeric_error=str(max_error),
    formula_mismatches=0,causal_future_or_forming_rows=0,window_or_gap_metadata_mismatches=0,
    paired_window_or_er_mismatches=0,repeated_native_close_mismatches=0,
    decimal_threshold_classification_mismatches=0,tick_rounded_classification_mismatches=0,
    minimum_observed_distance_to_threshold=str(min(Decimal(r['nearest_threshold_distance']) for r in audit_rows)),
    unavailable_observations=0,
    missing_branch='No missing native decision occurred; unavailable handling is runtime fixture-tested only.',
    outcome_counts={a:dict(Counter(r['outcome'] for r in rs)) for a,rs in arms.items()},
    outcome_by_month={a:{m:dict(Counter(r['outcome'] for r in rs if r['decision_at'].startswith(m)))
        for m in ('2025.02','2025.03')} for a,rs in arms.items()},
    unique_native_h1_closes_logged=len(native_points),independent_decimal_fixtures=len(fixture_rows),
    gap_windows_per_arm={a:sum(r['gap_count']!='0' for r in rs) for a,rs in arms.items()},
    span_hours_min=min(r['span_hours'] for r in audit_rows),
    span_hours_max=max(r['span_hours'] for r in audit_rows),
    last_close_age_seconds_max=max(r['last_close_age_seconds'] for r in audit_rows),
    proxy_status_counts_by_arm={a:dict(Counter(r['status'] for r in proxy_rows if r['arm']==a)) for a in arms},
    proxy_classification_disagreements=sum(r.get('proxy_low','')!='' and r['proxy_low']!=r['native_low'] for r in proxy_rows),
    all_logged_native_h1_closes_match_observed_m5_hour_last_close=True,
    observed_m5_parity_limit='Pre-start native H1 bars have no in-run M5 coverage; comparison is only where M5 exists.',
    incomplete_proxy_hours_by_arm=partial_hours_by_arm,
    source_clock='broker/source time; UTC mapping is unverified',source_hashes=hashes)

write('decimal_all_rows.csv',audit_rows)
write('native_vs_complete_m5_proxy.csv',proxy_rows)
write('paired_decisions.csv',paired)
write('unmatched_decisions.csv',unmatched)
write('runtime_tests.csv',test_rows)
write('native_logged_h1_closes.csv',native_points)
write('independent_decimal_fixtures.csv',fixture_rows)
(OUT/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(summary,indent=2,ensure_ascii=False))
