"""Descriptive observer study. No thresholds fitted; no changes to actual orders."""
import argparse
from calendar import timegm
from collections import defaultdict, Counter
from datetime import datetime
import json
from pathlib import Path
import re
from statistics import mean
from analyze_relative_search import read_csv, write_csv, months
from analyze_m5_context import parity, extended_stats
from tick_quality import audit, execution_blocks

TFS=('M15','H1','H4')
def stamp(s): return datetime.strptime(s,'%Y.%m.%d %H:%M:%S')

def verify_context(r):
    when=stamp(r['time']);decision=stamp(r['decision_time'])
    assert decision<=when
    assert all(stamp(r[k])<=decision for k in ('asof','break_time','break_bar','break_confirmed'))
    assert r['m15_reference_equal']=='1'
    if r['range_valid']=='1':
        assert r['history_complete']=='1' and int(r['closed_bars'])>=1198
        high,low=float(r['structure_high']),float(r['structure_low']);assert high>low
        raw=(float(r['price'])-low)/(high-low)
        assert abs(raw-float(r['raw_position']))<1e-8
        assert r['position']==('LOW' if raw<=1/3 else 'MID' if raw<=2/3 else 'HIGH')
        assert r['location']==('BELOW' if raw<0 else 'ABOVE' if raw>1 else 'INSIDE')
    else:
        assert r['position']=='UNKNOWN' and r['location']=='UNKNOWN' and r['raw_position']==''
    assert abs(float(r['spread_price'])-(float(r['ask'])-float(r['bid'])))<1e-8
    assert float(r['atr'])>0
    assert abs(float(r['spread_atr'])-float(r['spread_price'])/float(r['atr']))<1e-8
    assert int(r['server_hour'])==decision.hour

def shadow(c,path):
    entry,sl,tp=[float(c[k]) for k in ('price','planned_sl','planned_tp')];risk=entry-sl
    out=dict(shadow_outcome='END_CENSORED',shadow_r=None,shadow_tp_capped_r=None,
             horizon_mfe_r=None,horizon_mae_r=None,shadow_exit_msc=None)
    if risk<=0 or tp<=entry:
        out['shadow_outcome']='INVALID_STOP';return out
    if not path:return out
    start=timegm(stamp(c['time']).timetuple())*1000
    assert all(int(p['first_msc'])>=start and int(p['last_msc'])>=int(p['first_msc']) for p in path)
    assert all(int(b['first_msc'])>int(a['last_msc']) for a,b in zip(path,path[1:]))
    out['horizon_mfe_r']=max(0,max((float(p['high_bid'])-entry)/risk for p in path))
    out['horizon_mae_r']=min(0,min((float(p['low_bid'])-entry)/risk for p in path))
    for p in path:
        op,hi,lo,cl=[float(p[k]) for k in ('open_bid','high_bid','low_bid','close_bid')]
        assert lo<=min(op,cl)<=max(op,cl)<=hi
        stop,target=lo<=sl,hi>=tp
        if stop and target:
            out.update(shadow_outcome='AMBIGUOUS_M1',shadow_exit_msc=int(p['last_msc']));return out
        if stop or target:
            # First observed quote through a barrier records a gap; otherwise barrier approximation.
            fill=op if op<=sl or op>=tp else (sl if stop else tp)
            out.update(shadow_outcome='SL' if stop else 'TP',shadow_r=(fill-entry)/risk,shadow_exit_msc=int(p['last_msc']))
            break
        if p['horizon_end']=='1':
            out.update(shadow_outcome='TIME',shadow_r=(cl-entry)/risk,shadow_exit_msc=int(p['last_msc']));break
    if out['shadow_r'] is not None:out['shadow_tp_capped_r']=min(out['shadow_r'],(tp-entry)/risk)
    return out

def flatten(rows):
    assert len(rows)==3 and {r['tf'] for r in rows}=={'PERIOD_'+t for t in TFS}
    first=rows[0]
    keys=('id','stage','time','decision_time','price','bid','ask','spread_price','spread_points','spread_atr','atr',
          'server_hour','server_weekday','execution_gate','spread_allowed','positions','daily_entries',
          'daily_cap','equity_cap','uncertain_send','planned_sl','planned_tp','hold_bars')
    for row in rows:
        verify_context(row)
        assert all(row[k]==first[k] for k in keys)
    result={k:first[k] for k in keys}
    for row in rows:
        result.update({row['tf'][7:].lower()+'_'+k:v for k,v in row.items() if k not in keys and k!='tf'})
    result['year']=first['time'][:4];result['month']=first['time'][:7].replace('.','-')
    return result

def check_run(folder):
    m=json.loads((folder/'metrics.json').read_text(encoding='utf-8-sig'));assert m['audit']['passed']
    logs=execution_blocks(m['report'],folder/'journals/Tester');assert len(logs)==1
    text='\n'.join(logs[0]);assert 'thread finished' in text
    assert not re.search(r'array out of range|zero divide|critical error|DC_CAUSAL_OR_PARITY_FAILURE',text,re.I)
    risks=re.findall(r'RISK volume=[\d.]+ expected_loss=([\d.]+) budget=([\d.]+)',text)
    assert all(float(a)<=float(b)+.00011 for a,b in risks)
    groups=defaultdict(list);paths=defaultdict(list)
    for r in read_csv(folder/'context.csv',';'):groups[(r['stage'],r['id'])].append(r)
    for r in read_csv(folder/'path.csv',';'):paths[r['id']].append(r)
    candidates={key[1]:flatten(v) for key,v in groups.items() if key[0]=='CANDIDATE'}
    entries={key[1]:flatten(v) for key,v in groups.items() if key[0]=='ENTRY'}
    assert set(paths)==set(candidates) and set(entries)<=set(candidates)
    funnel=read_csv(folder/'funnel.csv',';')
    assert {r['time'] for r in funnel if r['signal'] in ('true','1')}==set(candidates)
    quality=audit(m['report'],folder/'journals/Tester')
    trades=read_csv(folder/'trades.csv');assert len(trades)==len(entries)
    trade_by_time={t['entry_time']:t for t in trades};assert len(trade_by_time)==len(trades)
    actual=[]
    for ident,e in entries.items():
        t=trade_by_time[stamp(e['time']).isoformat(sep=' ')]
        assert abs(float(t['entry_price'])-float(e['price']))<1e-8
        assert candidates[ident]['execution_gate']=='1'
        actual.append(dict(e,**t,tick_quality=quality['category']))
    out=[]
    for ident,c in candidates.items():
        reasons=[]
        if c['spread_allowed']=='0':reasons.append('SPREAD')
        for key in ('daily_cap','equity_cap','uncertain_send'):
            if c[key]=='1':reasons.append(key.upper())
        if int(c['positions'])>0:reasons.append('POSITION_OCCUPIED')
        cap=int(m['report']['inputs']['InpMaxTradesPerDay'])
        if cap>0 and int(c['daily_entries'])>=cap:reasons.append('DAILY_TRADE_COUNT')
        if ident not in entries and not reasons:reasons.append('OTHER_GATE_OR_ORDER_REJECTION')
        out.append(dict(c,executed=int(ident in entries),gate_flags='|'.join(reasons),
                        tick_quality=quality['category'],**shadow(c,paths[ident])))
    write_csv(folder/'candidates_with_context.csv',out);write_csv(folder/'trades_with_context.csv',actual)
    (folder/'context_audit.json').write_text(json.dumps(dict(passed=True,candidates=len(out),entries=len(actual),
        risk_plans=len(risks),causal_context=True,m15_core_parity=True,quality=quality,
        invalid_ranges=sum(r['range_valid']=='0' for rows in groups.values() for r in rows)),indent=2))
    return out,actual

def spread_bin(x):
    x=float(x)
    return '0_to_0.10' if x<=.1 else '0.10_to_0.20' if x<=.2 else '0.20_to_0.30' if x<=.3 else 'above_0.30'

def summary(rows,actual):
    if actual:
        return dict(extended_stats(rows),excluded=0)
    vals=[float(r['shadow_r']) for r in rows if r['shadow_r'] not in (None,'')]
    loss=-sum(x for x in vals if x<0)
    capped=[float(r['shadow_tp_capped_r']) for r in rows if r['shadow_tp_capped_r'] not in (None,'')]
    mfes=[float(r['horizon_mfe_r']) for r in rows if r['horizon_mfe_r'] not in (None,'')]
    maes=[float(r['horizon_mae_r']) for r in rows if r['horizon_mae_r'] not in (None,'')]
    return dict(n=len(rows),n_closed=len(vals),excluded=len(rows)-len(vals),
        executed=sum(int(r['executed']) for r in rows),win_rate=mean(v>0 for v in vals) if vals else None,
        mean_price_r=mean(vals) if vals else None,pf_price_r=sum(v for v in vals if v>0)/loss if loss else None,
        mean_tp_capped_price_r=mean(capped) if capped else None,
        mean_horizon_mfe_r=mean(mfes) if mfes else None,mean_horizon_mae_r=mean(maes) if maes else None,
        **{f'horizon_reach_{level:g}r':mean(v>=level for v in mfes) if mfes else None for level in (1,1.2,1.5,2)})

def aggregate(rows,actual):
    groups=defaultdict(list)
    for r in rows:
        joint='|'.join(r[t.lower()+'_regime'] for t in TFS)
        spread=spread_bin(r['spread_atr']);hour=f"{int(r['server_hour'])//6*6:02d}-{int(r['server_hour'])//6*6+5:02d}"
        categories=[('ALL','ALL'),('JOINT_REGIME',joint),('SPREAD_ATR',spread),('SERVER_6H',hour),
                    ('JOINT_REGIME_SPREAD',joint+'|'+spread),('JOINT_REGIME_TIME',joint+'|'+hour),
                    ('JOINT_REGIME_SPREAD_TIME',joint+'|'+spread+'|'+hour)]
        for tf in TFS:
            categories.append((tf+'_REGIME_POSITION',r[tf.lower()+'_regime']+'_'+r[tf.lower()+'_position']))
        for year in ('ALL',r['year']):
            for axis,key in categories:groups[(year,axis,key)].append(r)
    return [dict(period=k[0],axis=k[1],category=k[2],small_sample=len(v)<30,**summary(v,actual)) for k,v in sorted(groups.items())]

def analyze(batch,package):
    spec=json.loads((package/'manifest.json').read_text());candidates=[];actual=[];monthly=[]
    for run in spec['runs']:
        c,t=check_run(batch/run['run_id'])
        if run['stage']=='Control':continue
        candidates.extend(dict(r,run_id=run['run_id']) for r in c)
        actual.extend(dict(r,run_id=run['run_id']) for r in t)
        for month in months(run['date_from'],run['date_to']):
            monthly.append(dict(run_id=run['run_id'],month=month,candidates=sum(r['month']==month for r in c),
                executions=sum(r['month']==month for r in t),shadow_ambiguous=sum(r['month']==month and r['shadow_outcome']=='AMBIGUOUS_M1' for r in c)))
    write_csv(batch/'candidates_with_context.csv',candidates);write_csv(batch/'trades_with_context.csv',actual)
    write_csv(batch/'shadow_environment_statistics.csv',aggregate(candidates,False))
    write_csv(batch/'actual_environment_statistics.csv',aggregate(actual,True))
    write_csv(batch/'monthly_counts.csv',monthly)
    counts=Counter((r['year'],r['gate_flags'] or 'EXECUTED') for r in candidates)
    write_csv(batch/'execution_gate_counts.csv',[dict(year=k[0],flags=k[1],n=n) for k,n in sorted(counts.items())])
    s=summary(candidates,False);a=extended_stats(actual)
    text=f'''# M5 / M15-H1-H4 descriptive observer

No context filter, adaptive RR or parameter search. Known periods; not OOS.

- Raw candidates: {len(candidates)}; actual executions: {len(actual)}.
- Shadow: {json.dumps(s)}
- Actual: {json.dumps(a)}
- Mean actual monthly count: {len(actual)/len(monthly):.2f}; minimum: {min(r['executions'] for r in monthly)}.

## Interpretation
Use candidates_with_context.csv for all raw signals including spread/cap/position rejections.
Use trades_with_context.csv for broker-report executions and actual cash costs.
Shadow is a fixed-entry minute-Bid approximation, includes spread but excludes commission/swap/margin and broker rejection.
AMBIGUOUS_M1 (both SL/TP touched in the exit minute), invalid stops and END_CENSORED remain rows but are excluded from expectancy.
Horizon MFE/MAE covers 18 M5 bars, including after an earlier barrier exit; it is a label only, not pre-entry information.
TP-capped R is an outlier diagnostic, not a new exit replay. Negative gaps remain uncapped.
UNKNOWN positions include inverted/zero ranges; no synthetic range is substituted.
Hours are broker-server clock, NOT UTC/JST or DST-adjusted sessions. Tick quality is recorded per run.

Statistics include yearly marginals and predeclared joint regime/spread/time cells. Cells below 30 rows are flagged;
30 is a warning threshold, not proof of reliability. Shared periods/nearby candidates are dependent.
Do not select the best of these many cells. Require consistent yearly effect, enough independent samples and new-period confirmation.
No condition is promoted and no profitability claim is made.
'''
    (batch/'summary.md').write_text(text,encoding='utf-8')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--run',type=Path);ap.add_argument('--reference',type=Path)
    ap.add_argument('--batch',type=Path);ap.add_argument('--package',type=Path);args=ap.parse_args()
    if args.run:
        check_run(args.run)
        if args.reference:parity(args.run,args.reference)
    else:analyze(args.batch,args.package)
