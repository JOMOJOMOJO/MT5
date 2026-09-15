"""Evaluate a frozen artifact; this file contains no model fitting or selection."""
from __future__ import annotations
import argparse
import csv
import html
import json
import re
from pathlib import Path
import numpy as np
import pandas as pd
import analyze_technical_discovery as core
from analyze_technical_4m2m_real import ROOT, BATCH, OUT, load_months, sha
from technical_discovery_independent_recalculation import score, aggregate
from reconcile_technical_candidate import stats as actual_stats

VALIDATION=ROOT/'reports/backtest/batches/tstech_4m2m_validation_r2_20260911'


def verify_freeze():
    freeze=json.loads((OUT/'freeze_record.json').read_text())
    assert sha(OUT/'frozen_model.json')==freeze['frozen_model_sha256']
    hashes=pd.read_csv(VALIDATION/'source_hashes.csv',encoding='utf-8-sig')
    for row in hashes.itertuples():assert sha(row.Path)==row.Hash.lower(),row.Path
    hashes=pd.read_csv(VALIDATION/'pre_holdout_artifact_hashes.csv',encoding='utf-8-sig')
    for row in hashes.itertuples():assert sha(row.Path)==row.Hash.lower(),row.Path
    parity=pd.read_csv(VALIDATION/'parity/results.csv')
    assert len(parity)==11230 and (parity.status=='PASS').all()
    return json.loads((OUT/'frozen_model.json').read_text())


def python_holdout():
    model=verify_freeze()
    dest=OUT/'locked_holdout'
    dest.mkdir(exist_ok=False)
    f,o,hashes=load_months((202505,202506))
    x=f[model['features']].apply(pd.to_numeric,errors='coerce').to_numpy(float)
    ls=np.array([score(model['models']['long'],v) for v in x])
    ss=np.array([score(model['models']['short'],v) for v in x])
    signals=f[['episode_id','symbol','t0_msc','t0_processing_msc','market_cluster_id','month']].copy()
    signals['long_score']=ls;signals['short_score']=ss
    signals['direction']=np.where((np.maximum(ls,ss)<model['threshold'])|(ls==ss),0,np.where(ls>ss,1,-1))
    group=o[o.distance_index==model['distance_index']]
    actions=core.choose_actions(group,f,ls,ss)
    alltrades=[];checks=[];monthly=[];costs=[]
    for month in (202505,202506):
        eligible=actions[actions.month==month]
        trades,skips=core.portfolio(eligible,model['threshold'])
        # Independently rebuild reservations from plain records.
        busy=-1;independent=[]
        for r in sorted(eligible.to_dict('records'),key=lambda r:(r['signal_processing_msc'],r['t0_msc'],r['episode_id'])):
            if r['score']<model['threshold'] or r['signal_processing_msc']<=busy:continue
            if r['status'] in ('TP','SL','TIME','TIMEOUT'):
                independent.append(r['episode_id']);busy=r['exit_msc']
            elif r['status']=='NO_ENTRY':busy=max(busy,r['signal_processing_msc'],r['t0_msc']+30000)
            elif r['status']=='CENSORED':busy=max(busy,r['entry_msc']+900000)
            elif pd.notna(r['entry_msc']) and r['entry_msc']>0:busy=max(busy,r['entry_msc'])
        checks.append(dict(check=f'{month}_portfolio_episode_order',status='PASS' if independent==trades.episode_id.tolist() else 'FAIL',actual=len(independent)))
        summary=core.profit_stats(trades)
        oracle=aggregate(trades.to_dict('records'),.2)
        for key in ('trades','total_r','expectancy_r','pf','maxdd_r'):
            a=summary[key];b=oracle[key]
            ok=np.isclose(a,b,rtol=0,atol=1e-7,equal_nan=True)
            checks.append(dict(check=f'{month}_price_arithmetic_{key}',status='PASS' if ok else 'FAIL',actual=b,expected=a))
        monthly.append(dict(month=month,scope='LOCKED_PYTHON_HOLDOUT',**skips,**summary))
        costs.extend(dict(month=month,extra_cost_pips=c,**core.profit_stats(trades,c)) for c in core.COSTS)
        alltrades.append(trades)
    core.dump_csv(signals,dest/'signals.csv')
    core.dump_csv(pd.concat(alltrades,ignore_index=True),dest/'trades.csv')
    core.dump_csv(monthly,dest/'monthly.csv')
    core.dump_csv(costs,dest/'cost_sensitivity.csv')
    core.dump_csv(hashes,dest/'input_hashes.csv')
    core.dump_csv(checks,dest/'independent_checks.csv')
    assert all(c['status']=='PASS' for c in checks)
    print(json.dumps(core.clean_json(monthly),indent=2))


def journal_block(rid):
    agent=ROOT.parents[4]/'Tester'/ROOT.parents[2].name
    for path in sorted(agent.glob('Agent-*/logs/*.log'),key=lambda p:p.stat().st_mtime,reverse=True)[:64]:
        raw=path.read_bytes()
        lines=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig',errors='replace').splitlines()
        found=[i for i,s in enumerate(lines) if s.rstrip().endswith('InpRunId='+rid)]
        if not found:continue
        idx=found[-1]
        start=next(i for i in range(idx-1,-1,-1) if 'started with inputs:' in lines[i])
        end=next((i for i in range(idx+1,len(lines)) if 'started with inputs:' in lines[i]),len(lines))
        finished=next((i for i in range(idx+1,end) if 'Test passed in ' in lines[i]),None)
        if finished is not None:
            memory_line=next((i for i in range(finished+1,min(end,finished+12)) if 'memory used' in lines[i]),None)
            end=(memory_line+1) if memory_line is not None else finished+1
        return lines[max(0,start-8):end]
    raise RuntimeError('Matching journal absent: '+rid)


def mt5_month(month):
    model=verify_freeze()
    run=VALIDATION/str(month)
    qa=json.loads((run/'collection_qa.json').read_text())
    assert qa['status'] in ('PASS','PASS_WITH_LEGACY_WARNING')
    t=pd.read_csv(run/'candidate_trades.csv');s=pd.read_csv(run/'candidate_signals.csv');a=pd.read_csv(run/'candidate_actions.csv')
    f=core.csv(run/'technical_features.csv');reference=core.csv(BATCH/str(month)/'technical_features.csv')
    py=pd.read_csv(OUT/'locked_holdout/trades.csv');py=py[py.month==month]
    ps=pd.read_csv(OUT/'locked_holdout/signals.csv');ps=ps[ps.month==month]
    checks=[]
    def check(name,actual,expected=0):
        checks.append(dict(check=name,actual=actual,expected=expected,status='PASS' if actual==expected else 'FAIL'))
    check('feature_identity',set(map(tuple,f[['symbol','t0_msc']].values))==set(map(tuple,reference[['symbol','t0_msc']].values)),True)
    merged=f.merge(reference,on=['symbol','t0_msc'],suffixes=('_a','_b'),validate='one_to_one')
    mismatch=0
    for key in model['features']:
        mismatch+=int((~np.isclose(merged[key+'_a'].to_numpy(float),merged[key+'_b'].to_numpy(float),atol=1e-11,rtol=0,equal_nan=True)).sum())
    check('feature_mismatches',mismatch)
    both=s.merge(ps,on=['symbol','t0_msc'],suffixes=('_mt5','_py'),validate='one_to_one')
    check('signal_population',len(both),len(ps))
    check('signal_direction_mismatch',int((both.direction_mt5!=both.direction_py).sum()))
    check('signal_score_mismatch',int(((both.long_score_mt5-both.long_score_py).abs()>1e-10).sum()+((both.short_score_mt5-both.short_score_py).abs()>1e-10).sum()))
    check('duplicate_trade',int(t.episode_id.duplicated().sum()))
    check('entry_before_processing',int((t.entry_msc<t.processing_msc).sum()))
    check('entry_before_request',int((t.entry_msc<t.request_msc).sum()))
    check('quote_before_processing',int((t.quote_msc<t.processing_msc).sum()))
    check('quote_not_after_detection',int((t.quote_msc<=t.signal_msc).sum()))
    signal_quotes=t.merge(s[['episode_id','source_quote_msc']],on='episode_id',validate='one_to_one')
    check('quote_not_after_source',int((signal_quotes.quote_msc<=signal_quotes.source_quote_msc).sum()))
    settings=dict(line.split('=',1) for line in (run/'candidate.set').read_text(encoding='utf-8-sig').splitlines() if '=' in line)
    latency=int(settings['InpSubmitLatencyMs'].split('||')[0])
    quote_age=int(settings['InpMaxQuoteAgeMs'].split('||')[0])
    check('quote_before_submit_latency',int((t.quote_msc<t.processing_msc+latency).sum()))
    check('stale_request_quote',int((t.request_msc-t.quote_msc>quote_age).sum()))
    check('future_quote',int((t.quote_msc>t.request_msc).sum()))
    check('exit_before_entry',int((t.exit_msc<t.entry_msc).sum()))
    check('volume_reconciliation',int(((t.filled_volume-t.closed_volume).abs()>1e-8).sum()))
    check('net_profit_reconciliation',int(((t.net_profit-t.gross_profit-t.commission-t.fee-t.swap).abs()>1e-7).sum()))
    check('net_r_reconciliation',int(((t.net_profit/t.risk_amount-t.net_r).abs()>1e-7).sum()))
    risk=(t.entry_price-t.sl).abs()
    check('rr_below_one',int(((t.tp-t.entry_price).abs()+1e-10<risk).sum()))
    chronological=t.sort_values('entry_msc')
    check('overlapping_positions',int((chronological.entry_msc.to_numpy()[1:]<chronological.exit_msc.to_numpy()[:-1]).sum()))
    specs=core.csv(BATCH/str(month)/'technical_outcomes.csv').groupby('symbol').pip_size.first()
    t['pip_size']=t.symbol.map(specs);t['pip_money']=t.risk_amount*t.pip_size/risk
    result=actual_stats(t)
    core.dump_csv([dict(month=month,**result)],run/'actual_metrics.csv')
    core.dump_csv([dict(month=month,**actual_stats(t,c)) for c in core.COSTS],run/'actual_cost_sensitivity.csv')
    core.dump_csv([dict(symbol=name,**actual_stats(g)) for name,g in t.groupby('symbol')],run/'actual_symbol_metrics.csv')
    t['t0_msc']=t.signal_msc
    compare=t.merge(py,on=['symbol','t0_msc','direction'],suffixes=('_mt5','_python'),how='outer',indicator=True,validate='one_to_one')
    core.dump_csv(compare,run/'python_trade_comparison.csv')
    differences=[]
    for row in compare[compare['_merge']!='both'].to_dict('records'):
        trace=a[(a.symbol==row['symbol'])&(a.t0_msc==row['t0_msc'])]
        differences.append(dict(symbol=row['symbol'],t0_msc=row['t0_msc'],direction=row['direction'],
                                presence=row['_merge'],mt5_actions=';'.join(trace.status.astype(str)),
                                python_status=row['status'],reason='Recorded execution-path difference, not model reselection'))
    core.dump_csv(pd.DataFrame(differences,columns=['symbol','t0_msc','direction','presence','mt5_actions','python_status','reason']),run/'trade_difference_causes.csv')
    over=t[t.hold_seconds>900].copy()
    over['overrun_seconds']=over.hold_seconds-900
    core.dump_csv(over[['episode_id','symbol','entry_msc','exit_msc','hold_seconds','overrun_seconds','exit_reason']],run/'hold_time_overruns.csv')
    core.dump_csv(a.groupby('status').size().rename('count').reset_index(),run/'action_counts.csv')
    block=journal_block(qa['run_id'])
    end=[x for x in block if 'technical_candidate signals=' in x]
    check('one_candidate_end_summary',len(end),1)
    if len(end)==1:
        counters=dict(re.findall(r'(signals|closed|errors|remaining_positions)=(\d+)',end[0]))
        check('candidate_errors',int(counters['errors']))
        check('remaining_positions',int(counters['remaining_positions']))
        check('closed_count',int(counters['closed']),len(t))
    evidence=[x for x in block if any(k in x for k in ('generating based on real ticks','technical_candidate signals=','Test passed in ','real ticks discarded','memory used','final balance','technical_discovery episodes='))]
    (run/'execution_journal_excerpt.txt').write_text('\n'.join(evidence)+'\n',encoding='utf-8')
    # Independent HTML financial reconciliation; exclude identifying account fields.
    raw=(run/'tester_report.html').read_bytes();ht=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig',errors='replace')
    fields=[]
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',ht,re.S|re.I):
        cells=[html.unescape(re.sub('<[^>]+>','',v)).strip() for v in re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S|re.I)]
        for i,c in enumerate(cells[:-1]):
            if any(k in c for k in ('Total Net Profit','総損益','Total Trades','総取引数','取引数','Profit Factor','プロフィットファクター','Drawdown','ドローダウン')):
                fields.append(dict(field=c,value=cells[i+1]))
    core.dump_csv(fields,run/'tester_financial_fields.csv')
    netfield=next((v['value'] for v in fields if 'Total Net Profit' in v['field'] or '総損益' in v['field']),None)
    check('tester_net_field_observed',netfield is not None,True)
    if netfield is not None:
        amount=float(re.sub(r'[^0-9.\-]','',netfield))
        check('tester_net_profit_difference_over_cent',abs(amount-result['net_profit'])>.011,False)
    core.dump_csv(checks,run/'qa_checks.csv')
    core.write_json(dict(month=month,actual=result,qa_failures=sum(c['status']=='FAIL' for c in checks),
                         python_matched=int((compare['_merge']=='both').sum()),mt5_only=int((compare['_merge']=='left_only').sum()),
                         python_only=int((compare['_merge']=='right_only').sum()),model_sha256=sha(OUT/'frozen_model.json')),
                    run/'reconciliation.json')
    print(json.dumps(core.clean_json(result),indent=2))
    assert all(c['status']=='PASS' for c in checks),str(run/'qa_checks.csv')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--python-holdout',action='store_true');p.add_argument('--month',type=int)
    args=p.parse_args()
    if args.python_holdout:python_holdout()
    if args.month:mt5_month(args.month)
