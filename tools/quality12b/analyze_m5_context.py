"""Fixed M5/M15 policy replay analysis; no policy or threshold fitting."""
import argparse
import csv
import json
import re
from collections import defaultdict,Counter
from datetime import datetime
from pathlib import Path
from statistics import mean
from analyze_relative_search import stats,months,write_csv,read_csv
from tick_quality import audit,execution_blocks

def stamp(x):return datetime.strptime(x,'%Y.%m.%d %H:%M:%S')

def extended_stats(trades):
    result=stats(trades)
    capped=[min(float(t['implied_initial_r_price']),float(t['planned_reward_r_price'])) for t in trades]
    loss=-sum(x for x in capped if x<0)
    result.update(mean_tp_capped_price_r=mean(capped) if capped else None,
                  pf_tp_capped_price_r=sum(x for x in capped if x>0)/loss if loss else None,
                  overshoot_trades=sum(float(t['tp_overshoot_initial_r'] or 0)>.05 for t in trades))
    return result

def check_run(folder):
    m=json.loads((folder/'metrics.json').read_text(encoding='utf-8-sig'))
    assert m['audit']['passed']
    logs=execution_blocks(m['report'],folder/'journals/Tester');assert len(logs)==1
    text='\n'.join(logs[0]);assert 'thread finished' in text
    assert not re.search(r'array out of range|zero divide|critical error|MC_CAUSAL_FAILURE',text,re.I)
    risks=re.findall(r'RISK volume=[\d.]+ expected_loss=([\d.]+) budget=([\d.]+)',text)
    assert all(float(a)<=float(b)+.00011 for a,b in risks)
    contexts=read_csv(folder/'m15.csv',';')
    for r in contexts:
        when=stamp(r['time'])
        assert all(stamp(r[k])<=when for k in ('asof','break_time','break_confirmed','decision_time'))
        if r['regime']!='UNKNOWN':
            assert int(r['closed_m15_bars'])>=1198
            raw=(float(r['ask_or_fill'])-float(r['structure_low']))/(float(r['structure_high'])-float(r['structure_low']))
            assert abs(raw-float(r['raw_position']))<1e-8
            pos='LOW' if raw<=1/3 else ('MID' if raw<=2/3 else 'HIGH')
            assert r['position']==pos
    entries=[r for r in contexts if r['stage']=='ENTRY']
    trades=read_csv(folder/'trades.csv')
    assert len(entries)==len(trades)==len(risks),(len(entries),len(trades),len(risks))
    joined=[]
    for t,e in zip(trades,entries):
        assert t['entry_time']==stamp(e['time']).isoformat(sep=' ')
        assert abs(float(t['entry_price'])-float(e['ask_or_fill']))<1e-8
        joined.append(dict(t,**{'m15_'+k:v for k,v in e.items()}))
    q=audit(m['report'],folder/'journals/Tester')
    (folder/'context_audit.json').write_text(json.dumps(dict(passed=True,entries=len(entries),risk_plans=len(risks),
            causal_context=True,quality=q['category'],fallback_lines=q['fallback_line_count']),indent=2))
    write_csv(folder/'trades_with_m15.csv',joined)
    return joined,contexts,q

def parity(folder,reference):
    from analyze_reports import analyze_report
    from compare_reproduction import CORE_FIELDS
    _,old=analyze_report(reference)
    new=read_csv(folder/'trades.csv')
    assert len(old)==len(new)
    for a,b in zip(old,new):
        for k in CORE_FIELDS+('net','swap'):
            assert str(a[k])==str(b[k]),(k,a[k],b[k])
    (folder/'observer_parity.json').write_text(json.dumps(dict(passed=True,trades=len(new),exact_costs=True)))

def analyze(batch,package):
    spec=json.loads((package/'manifest.json').read_text())
    results=[];categories=[];monthly=[];annual=[];candidate_monthly=[];base_times={}
    for run in spec['runs']:
        d=batch/run['run_id'];trades,ctx,q=check_run(d)
        if run['stage'] not in ('Search','Validate'): continue
        mon=months(run['date_from'],run['date_to'])
        candidates=[r for r in ctx if r['stage']=='CANDIDATE']
        times=[r['time'] for r in candidates]
        assert len(times)==len(set(times))
        if run['stage'] in base_times:assert times==base_times[run['stage']]
        else:base_times[run['stage']]=times
        counts=Counter(t['entry_time'][:7] for t in trades)
        for month in mon:
            monthly.append(dict(run_id=run['run_id'],stage=run['stage'],month=month,n=counts[month]))
        for year in sorted({x[:4] for x in mon}):
            annual.append(dict(run_id=run['run_id'],year=year,**extended_stats([t for t in trades if t['entry_time'].startswith(year)])))
        groups=defaultdict(list)
        for t in trades:groups[(t['m15_regime'],t['m15_position'])].append(t)
        for regime in ('UP','DOWN','RANGE','UNKNOWN'):
            for position in ('LOW','MID','HIGH','UNKNOWN'):
                if regime!='UNKNOWN' and position=='UNKNOWN':continue
                if regime=='UNKNOWN' and position!='UNKNOWN':continue
                categories.append(dict(run_id=run['run_id'],regime=regime,position=position,**extended_stats(groups[(regime,position)])))
        for month in mon:
            for regime in ('UP','DOWN','RANGE','UNKNOWN'):
                candidate_monthly.append(dict(run_id=run['run_id'],month=month,regime=regime,
                    n=sum(r['time'][:7].replace('.','-')==month and r['regime']==regime for r in candidates)))
        results.append(dict(run_id=run['run_id'],cell=run['cell'],stage=run['stage'],**extended_stats(trades),
            raw_candidates=len(candidates),policy_rejected=sum(r['policy_allowed']=='false' for r in candidates),
            avg_monthly=len(trades)/len(mon),min_monthly=min(counts[x] for x in mon),quality=q['category']))
    write_csv(batch/'policy_statistics.csv',results)
    write_csv(batch/'m15_regime_position.csv',categories)
    write_csv(batch/'monthly_counts.csv',monthly)
    write_csv(batch/'annual_statistics.csv',annual)
    write_csv(batch/'candidate_monthly_context.csv',candidate_monthly)
    # Apply preregistered gate; no best-on-validation selection or automatic adoption.
    decisions=[]
    for r in results:
        if r['stage']!='Search' or r['cell']=='hold270_control':continue
        ys=[y for y in annual if y['run_id']==r['run_id']]
        base=next(v for v in results if v['run_id']=='search_fixed_1p5')
        passed=(all(y['n']>=36 and y['net']>0 and (y['pf'] or 0)>=1.1 and
                    (y['mean_tp_capped_price_r'] or 0)>0 for y in ys)
                and r['mean_tp_capped_price_r'] is not None
                and r['mean_tp_capped_price_r']>(base['mean_tp_capped_price_r'] if base['mean_tp_capped_price_r'] is not None else -999))
        v=next(x for x in results if x['cell']==r['cell'] and x['stage']=='Validate')
        decisions.append(dict(cell=r['cell'],train_gate=passed,validation=v,adopted=False))
    (batch/'decisions.json').write_text(json.dumps(decisions,indent=2))
    lines=['# M5 execution / M15 context: fixed policy study','',
           'Known periods, not OOS. Price R excludes cash costs; net/PF includes report costs.',
           'TP-capped price R removes positive TP overshoot only; no equity/lot replay and no cap on negative gaps.',
           'No policy is automatically adopted. Inspect yearly results, monthly frequency, market-closed exits and tick quality.', '',
           '| Policy | Period | n | Net USD | PF | Price R | TP-capped price R | Monthly mean/min |',
           '|---|---|---:|---:|---:|---:|---:|---|']
    for r in results:
        lines.append(f"| {r['cell']} | {r['stage']} | {r['n']} | {r['net']:.2f} | {r['pf']} | {r['mean_price_r']} | {r['mean_tp_capped_price_r']} | {r['avg_monthly']:.2f}/{r['min_monthly']} |")
    (batch/'summary.md').write_text('\n'.join(lines)+'\n')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--batch',type=Path);ap.add_argument('--package',type=Path)
    ap.add_argument('--run',type=Path);ap.add_argument('--reference',type=Path)
    a=ap.parse_args()
    if a.run:
        check_run(a.run)
        if a.reference:parity(a.run,a.reference)
    else:analyze(a.batch,a.package)
