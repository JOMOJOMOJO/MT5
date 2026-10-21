"""Attribute original spread gate rejections; no threshold or trading changes."""
import argparse
from collections import Counter, defaultdict
import csv
from decimal import Decimal
import json
from pathlib import Path
from analyze_reports import analyze_report
from compare_reproduction import CORE_FIELDS, OPERATIONAL
from tick_quality import audit


def classify(row):
    if row['tick_ok'] != '1':
        return 'TICK_API_FAILURE'
    if Decimal(row['pip']) <= 0:
        return 'INVALID_PIP'
    if Decimal(row['raw_spread_pips']) < 0:
        return 'NEGATIVE_SPREAD'
    if row['raw_allowed'] == '1':
        return 'PASS'
    # Independently compute a grid-based comparison from quote precision.
    point = Decimal(row['point'])
    if point > 0:
        gap = (Decimal(row['ask'])-Decimal(row['bid']))/point
        rounded = gap.to_integral_value()
        if abs(gap-rounded) < Decimal('0.000001') and rounded <= Decimal(row['limit_pips'])*Decimal(row['pip'])/point:
            return 'FLOAT_BOUNDARY_ONLY'
    return 'ABOVE_LIMIT'


def analyze(run, reference):
    m, trades = analyze_report(run/'report.htm')
    old, prior = analyze_report(reference)
    errors = []
    if not m['audit']['passed'] or not old['audit']['passed']:
        errors.append('Report accounting audit failed')
    for k in ('broker','currency','symbol','timeframe','from_date','to_date'):
        if m['report'][k] != old['report'][k]: errors.append('Identity differs: '+k)
    for k in ('bars','ticks','initial_deposit'):
        if m['reported'][k] != old['reported'][k]: errors.append('History/count differs: '+k)
    if {k:v for k,v in m['report']['inputs'].items() if k not in OPERATIONAL} != {k:v for k,v in old['report']['inputs'].items() if k not in OPERATIONAL}:
        errors.append('Nonoperational inputs differ')
    if len(trades) != len(prior): errors.append('Trade count differs')
    diffs=[]
    for a,b in zip(prior,trades):
        changed=[k for k in CORE_FIELDS if a[k]!=b[k]]
        if changed: diffs.append(dict(entry=a['entry_time'],fields=changed))
        if Decimal(str(b['net']))-Decimal(str(a['net'])) != Decimal(str(b['swap']))-Decimal(str(a['swap'])):
            errors.append('Non-swap P/L difference at '+a['entry_time'])
    if diffs: errors.append('Trade execution differs')
    quotes=list(csv.DictReader((run/'spread.csv').open(encoding='utf-8-sig'),delimiter=';'))
    reasons=Counter()
    months=defaultdict(Counter)
    perday=Counter()
    distribution=Counter()
    samples=defaultdict(list)
    seen=set()
    for r in quotes:
        reason=classify(r)
        if reason!=r['reason']: errors.append('Reason mismatch at '+r['time'])
        if r['bar_time'] in seen: errors.append('Duplicate entry gate bar '+r['bar_time'])
        seen.add(r['bar_time'])
        reasons[reason]+=1
        months[r['bar_time'][:7]][reason]+=1
        if reason!='PASS': perday[r['bar_time'][:10]]+=1
        distribution[(reason,r['point_gap_rounded'],r['symbol_spread_points'])]+=1
        if len(samples[reason])<5:samples[reason].append(r)
    if not quotes: errors.append('No quote observations')
    def telemetry_counts(path):
        sums={}
        day=None
        with path.open(encoding='utf-8-sig') as f:
            for r in csv.DictReader(f,delimiter=';'):
                if r['event']=='day_reset':day=r['timestamp'][:10]
                if r['event']=='daily_summary':
                    if day in sums:errors.append('Duplicate daily telemetry '+day)
                    sums[day]=int(r['blocked_spread'])
        return sums
    current=telemetry_counts(run/'telemetry.csv')
    baseline=telemetry_counts(reference.parent/'telemetry.csv')
    if current != baseline: errors.append('Daily gate counts differ from original run')
    if any(perday[d]!=n for d,n in current.items()) or any(d not in current for d in perday):
        errors.append('Quote rejection counts differ from daily telemetry')
    q=audit(m['report'],run/'journals/Tester')
    result=dict(passed=not errors,errors=errors,trades=len(trades),exact_trade_core_match=not diffs and len(trades)==len(prior),
                core_differences=diffs,quote_observations=len(quotes),reasons=dict(reasons),
                daily_gate_counts_match_baseline=current==baseline,months=dict(months),examples=dict(samples),
                tick_quality=q,source_report_sha256=m['report']['sha256'],reference_report_sha256=old['report']['sha256'],
                scope='Only original entry-gate calls; original return preserved. Grid comparison is a diagnostic counterfactual, not used to place orders.',
                limit='Tester-observed quotes do not prove those quotes were executable historically at a live broker.')
    (run/'spread_diagnosis.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    with (run/'spread_distribution.csv').open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.writer(f);w.writerow(['reason','point_gap_rounded','symbol_spread_points','count'])
        w.writerows((*k,n) for k,n in sorted(distribution.items()))
    with (run/'spread_monthly.csv').open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.writer(f);w.writerow(['month','reason','count'])
        w.writerows((month,reason,n) for month,c in sorted(months.items()) for reason,n in sorted(c.items()))
    print(json.dumps({k:result[k] for k in ('passed','errors','trades','quote_observations','reasons','daily_gate_counts_match_baseline')}))
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run',type=Path,required=True)
    p.add_argument('--reference',type=Path,required=True)
    a=p.parse_args()
    raise SystemExit(0 if analyze(a.run,a.reference)['passed'] else 2)
