"""Causal context and preregistered exit screening on fixed baseline entries.

Uses observed post-entry Bid minute bars, not a replacement for MT5 order tests.
All dual SL/TP minute touches are conservatively excluded. No threshold search.
"""
import argparse
import csv
from collections import defaultdict
from datetime import datetime
from decimal import Decimal,ROUND_HALF_UP
import json
from pathlib import Path
from statistics import mean,median
from analyze_reports import analyze_report
from compare_reproduction import CORE_FIELDS,OPERATIONAL
from tick_quality import audit

POLICIES=('FIXED22_RR1','FIXED22_RR1P5','FIXED22_RR2','H1_LOW_RR1P5','H4_LOW_RR1P5')


def read(path,delimiter=','):
    with path.open(encoding='utf-8-sig') as f:return list(csv.DictReader(f,delimiter=delimiter))


def write(path,rows):
    if not rows:return
    with path.open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)


def simulate(entry,sl,rr,path):
    e=Decimal(str(entry)).quantize(Decimal('.001'),rounding=ROUND_HALF_UP)
    s=Decimal(str(sl)).quantize(Decimal('.001'),rounding=ROUND_HALF_UP)
    target=(e+(e-s)*Decimal(str(rr))).quantize(Decimal('.001'),rounding=ROUND_HALF_UP)
    entry,sl,risk=float(e),float(s),float(e-s)
    result=dict(sl=sl,tp=float(target),sl_pips=risk/.01,rr=rr,outcome='END_CENSORED',result_r=None,exit_msc=None,
                horizon_mfe_r=None,horizon_mae_r=None)
    if sl<=0 or risk<=0:
        result['outcome']='INVALID_STOP';return result
    if not path:return result
    result['horizon_mfe_r']=max(0,max((float(p['high_bid'])-entry)/risk for p in path))
    result['horizon_mae_r']=min(0,min((float(p['low_bid'])-entry)/risk for p in path))
    tp=result['tp']
    for p in path:
        op,hi,lo,cl=[float(p[k]) for k in ('open_bid','high_bid','low_bid','close_bid')]
        stop=lo<=sl;target=hi>=tp
        # Exact within-minute order is intentionally not inferred from OHLC.
        if stop and target:
            result.update(outcome='AMBIGUOUS_M1',exit_msc=int(p['last_msc']));return result
        if stop or target:
            level=sl if stop else tp
            fill=op if op<=sl or op>=tp else level
            result.update(outcome='SL' if stop else 'TP',result_r=(fill-entry)/risk,exit_msc=int(p['last_msc']))
            return result
        if p['horizon_end']=='1':
            result.update(outcome='TIME',result_r=(cl-entry)/risk,exit_msc=int(p['last_msc']));return result
    return result


def stats(rows):
    values=[float(r['result_r']) for r in rows if r['result_r'] not in (None,'')]
    positive=sum(v for v in values if v>0);negative=-sum(v for v in values if v<0)
    years=defaultdict(list)
    for r in rows:
        if r['result_r'] not in (None,''):years[r['year']].append(float(r['result_r']))
    return dict(n=len(rows),n_closed=len(values),n_ambiguous=sum(r['outcome']=='AMBIGUOUS_M1' for r in rows),
                n_invalid=sum(r['outcome']=='INVALID_STOP' for r in rows),n_censored=sum(r['outcome']=='END_CENSORED' for r in rows),
                win_rate=sum(v>0 for v in values)/len(values) if values else None,
                expectancy_price_r=mean(values) if values else None,pf_price_r=positive/negative if negative else None,
                median_sl_pips=median(float(r['sl_pips']) for r in rows) if rows else None,
                equal_year_mean_r=mean(mean(v) for v in years.values()) if years else None,
                n_years=len(years),positive_years=sum(mean(v)>0 for v in years.values()))


def summarize(out,rows):
    groups=defaultdict(list)
    for r in rows:
        for period in ('ALL',r['year']):
            groups[(r['tick_quality'],r['policy'],period,'ALL','ALL')].append(r)
            for tf in ('M15','H1','H4'):
                groups[(r['tick_quality'],r['policy'],period,tf,r[tf+'_regime']+'_'+r[tf+'_position'])].append(r)
            groups[(r['tick_quality'],r['policy'],period,'H1xH4',r['H1_regime']+'_'+r['H4_regime'])].append(r)
    records=[dict(tick_quality=k[0],policy=k[1],period=k[2],tf=k[3],category=k[4],**stats(v)) for k,v in sorted(groups.items())]
    write(out/'context_exit_statistics.csv',records)
    monthly=defaultdict(list)
    for r in rows:monthly[(r['run_id'],r['policy'],r['entry_time'][:7])].append(r)
    write(out/'monthly_statistics.csv',[dict(run_id=k[0],policy=k[1],month=k[2],**stats(v)) for k,v in sorted(monthly.items())])


def analyze(run,reference):
    m,trades=analyze_report(run/'report.htm');old,prior=analyze_report(reference)
    errors=[]
    if not m['audit']['passed'] or not old['audit']['passed']:errors.append('Accounting failed')
    for key in ('symbol','broker','currency','timeframe','from_date','to_date'):
        if m['report'][key]!=old['report'][key]:errors.append('Identity '+key)
    if {k:v for k,v in m['report']['inputs'].items() if k not in OPERATIONAL}!={k:v for k,v in old['report']['inputs'].items() if k not in OPERATIONAL}:errors.append('Inputs differ')
    if len(trades)!=len(prior):errors.append('Trade count differs')
    for a,b in zip(prior,trades):
        if any(a[k]!=b[k] for k in CORE_FIELDS):errors.append('Execution differs '+a['entry_time'])
        if Decimal(str(b['net']))-Decimal(str(a['net']))!=Decimal(str(b['swap']))-Decimal(str(a['swap'])):errors.append('Non-swap cash difference')
    contexts=defaultdict(dict)
    for r in read(run/'context.csv',';'):
        if r['tf'] in contexts[r['id']]:errors.append('Duplicate context')
        contexts[r['id']][r['tf']]=r
        if r['asof']>r['entry_time']:errors.append('Future context')
        if r['m15_reference_equal']!='1':errors.append('M15 core parity failed')
    paths=defaultdict(list)
    for r in read(run/'path.csv',';'):paths[r['id']].append(r)
    quality=audit(m['report'],run/'journals/Tester')
    output=[]
    ids={t['entry_time'].replace('-','.') for t in trades}
    if set(contexts)!=ids or set(paths)!=ids:errors.append('Context/path population differs')
    for t in trades:
        key=t['entry_time'].replace('-','.')
        env=contexts.get(key,{})
        if set(env)!= {'PERIOD_M15','PERIOD_H1','PERIOD_H4'}:
            errors.append('Missing context '+key);continue
        path=paths.get(key,[])
        # Epoch timestamps are broker server clock treated as UTC, independent of local Windows TZ.
        from calendar import timegm
        entry_msc=timegm(datetime.strptime(key,'%Y.%m.%d %H:%M:%S').timetuple())*1000
        if any(int(p['first_msc'])<entry_msc for p in path):errors.append('Pre-entry path '+key)
        if any(int(a['last_msc'])>=int(b['first_msc']) for a,b in zip(path,path[1:])):errors.append('Unordered path '+key)
        entry=float(t['entry_price'])
        common=dict(run_id=run.name,year=key[:4],id=key,entry_time=t['entry_time'],entry=entry,tick_quality=quality['category'],actual_net=t['net'])
        for tf in ('M15','H1','H4'):
            r=env['PERIOD_'+tf]
            for field in ('regime','position','raw_position','location','high','low','break_direction','break_minutes','asof','history_complete'):
                common[tf+'_'+field]=r[field]
        definitions=[(POLICIES[0],entry-.22,1.),(POLICIES[1],entry-.22,1.5),(POLICIES[2],entry-.22,2.),
                     (POLICIES[3],float(common['H1_low'])-.01,1.5),(POLICIES[4],float(common['H4_low'])-.01,1.5)]
        for policy,sl,rr in definitions:output.append(dict(common,policy=policy,**simulate(entry,sl,rr,path)))
    validation=dict(passed=not errors,errors=errors,entry_count=len(trades),context_rows=sum(len(v) for v in contexts.values()),
                    history_counts_equal={k:m['reported'][k]==old['reported'][k] for k in ('bars','ticks')},quality=quality,
                    note='Exact baseline execution required. History count drift recorded separately; no assertion of byte-identical tick history. Exit comparison is OHLC shadow, not actual orders; cash costs excluded from price R.')
    (run/'context_validation.json').write_text(json.dumps(validation,indent=2)+'\n',encoding='utf-8')
    write(run/'exit_comparisons.csv',output);summarize(run,output)
    print(json.dumps(dict(passed=not errors,errors=errors,entries=len(trades),shadow_rows=len(output))))
    return not errors


def batch_summary(batch):
    rows=[]
    for d in batch.iterdir():
        if (d/'exit_comparisons.csv').exists():rows+=read(d/'exit_comparisons.csv')
    write(batch/'all_exit_comparisons.csv',rows);summarize(batch,rows)
    (batch/'analysis_notes.md').write_text('''# Collected context and fixed-entry exit screen

Per-year and per-data-quality statistics are in context_exit_statistics.csv.
Price R includes observed Ask-to-Bid spread but excludes commission/swap and intraminute gap/slippage.
Dual-touch M1 bars are excluded as AMBIGUOUS_M1. END_CENSORED and invalid stops are separate.
Each original executed entry is reused for five prespecified exits. These are paired shadows, not five independent datasets.
An exit change can change later eligibility; this screen is NOT an actual one-position portfolio replay.
Existing spread rule, including the known floating boundary issue, is unchanged.
No category-dependent live rule or threshold optimization has been applied.
All periods are previously seen or usage-unverified; none is called untouched OOS.
Use equal-year comparisons, quality-separated results and removal of the known weekend outlier as sensitivity only.
H1/H4 definitions are a timeframe generalization of the frozen M15 core; M15 parity is checked per entry.
1200-bar lookback is fixed; history_complete marks availability. UNKNOWN is retained.
''',encoding='utf-8')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--run',type=Path);p.add_argument('--reference',type=Path);p.add_argument('--batch',type=Path)
    a=p.parse_args()
    if a.batch:batch_summary(a.batch)
    else:raise SystemExit(0 if analyze(a.run,a.reference) else 2)
