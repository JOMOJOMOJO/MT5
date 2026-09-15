"""Resolve target journal mode and isolate subsystem integrity, without P/L."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path
import pandas as pd
from audit_technical_4m2m_input import keyvalues, sha, text_file, dump


def run(args):
    root,out=Path(args.input),Path(args.output)
    if out.exists(): raise ValueError('Refuse overwrite')
    out.mkdir(parents=True)
    logs=[Path(x) for x in args.journal]
    lines=[]
    for log in logs:
        lines.extend((str(log),i+1,line) for i,line in enumerate(text_file(log).splitlines()))
    markers=[i for i,(_,_,line) in enumerate(lines) if 'InpRunId='+root.name in line]
    if len(markers)!=1:raise ValueError('Target RunId must occur exactly once in supplied journal set')
    marker=markers[0]
    start=max(i for i in range(marker) if 'testing of Experts' in lines[i][2] and 'started with inputs:' in lines[i][2])
    mode=max(i for i in range(start) if any(s in lines[i][2] for s in ('every tick generating','generating based on real ticks')))
    finish=next(i for i in range(marker,len(lines)) if 'Test passed in ' in lines[i][2])
    later=[i for i in range(marker+1,finish) if 'started with inputs:' in lines[i][2]]
    if later:raise ValueError('Ambiguous intervening tester run')
    observed_mode='REAL_TICKS' if 'generating based on real ticks' in lines[mode][2] else 'GENERATED_EVERY_TICK'
    prefix=f'ExpectedValue_MultiCurrency_TickShockResearch_{root.name}_'
    summary_path=root/(prefix+'summary.csv')
    metadata_path=root/(prefix+'summary.csv.runmeta')
    summary=pd.read_csv(summary_path)
    meta=dict(x.split('=',1) for x in text_file(metadata_path).splitlines()[1].split('|') if '=' in x)
    integrity=keyvalues(summary.loc[summary.record_type.eq('INTEGRITY'),'value'].iloc[0])
    statistics=keyvalues(summary.loc[summary.record_type.eq('STATISTICAL_CLUSTER'),'value'].iloc[0])
    evidence=[]
    whitelist=re.compile(r'every tick generating|generating based on real ticks|testing with execution delay|testing of Experts|InpRunId=|InpLogFolder=|InpResearchPeriod=|InpTesterModel=|InpSourceCommit=|InpEx5Hash=|technical_discovery episodes=|technical_candidate signals=|Test passed in |total ticks for all symbols|Mb memory used')
    for file,number,line in lines[mode:finish+12]:
        if whitelist.search(line):evidence.append(dict(path=file,line_number=number,text=line))
    dump(evidence,out/'target_journal_evidence.csv')
    pool=[]
    for file,number,line in lines[start:finish+1]:
        if 'active event pool exhausted symbol=' not in line:continue
        match=re.search(r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*exhausted symbol=(\w+)',line)
        if not match:raise ValueError('Unparsed pool failure')
        pool.append(dict(encoded_time=match[1],symbol=match[2],journal_path=file,line_number=number))
    dump(pool,out/'legacy_pool_failure_occurrences.csv')
    p=pd.DataFrame(pool);p['month']=p.encoded_time.str[:7]
    dump(p.groupby(['month','symbol']).size().rename('failures').reset_index(),out/'legacy_pool_failures_by_month_symbol.csv')
    symbols=[]
    for row in summary[summary.record_type.eq('SYMBOL')].itertuples():
        values=keyvalues(row.value)
        fields={key:values.get(key,'') for key in ('last_quote_msc','read_through_msc','requested_to_msc',
            'last_copy_error','history_synchronized','read_failures','cursor_stalls','page_limits','final_drains','root_cause')}
        fields.update(symbol=row.key,ticks_processed=row.ticks)
        symbols.append(fields)
    dump(symbols,out/'symbol_final_frontiers.csv')
    checks=[]
    def check(name,actual,expected,scope):
        checks.append(dict(check=name,actual=actual,expected=expected,scope=scope,status='PASS' if actual==expected else 'FAIL'))
    check('target_real_tick_mode',observed_mode,'REAL_TICKS','FORMAL_INPUT_GATE')
    check('metadata_matches_actual_mode',meta.get('model')=='REAL_TICKS_MODEL_4' and observed_mode=='REAL_TICKS',True,'PROVENANCE')
    check('legacy_pool_failure_count_matches_summary',len(pool),int(integrity['event_pool_exhaustions']),'LEGACY_SCENARIO_POOL')
    check('statistical_tracking_capacity_hits',int(statistics['track_capacity_hits']),0,'EPISODE_PATH')
    for sym in symbols:
        check(sym['symbol']+'_read_through_final_requested',sym['read_through_msc'],sym['requested_to_msc'],'GLOBAL_TICK_FRONTIER')
        for key,expected in [('last_copy_error','0'),('history_synchronized','true'),('cursor_stalls','0'),('page_limits','0'),('final_drains','1'),('root_cause','')]:
            check(sym['symbol']+'_'+key,sym[key],expected,'GLOBAL_TICK_FRONTIER')
    ex5_hash=sha(args.ex5)
    check('current_ex5_matches_recorded_hash',ex5_hash,meta.get('ex5_hash','').lower(),'CURRENT_FILE_NOT_CONTEMPORANEOUS_PROOF')
    dump(checks,out/'scope_checks.csv')
    inputs=[summary_path,metadata_path,*logs,Path(args.ex5),Path(__file__)]
    dump([dict(path=str(x),bytes=x.stat().st_size,sha256=sha(x)) for x in inputs],out/'provenance_input_hashes.csv')
    result=dict(verdict='BLOCKED_WRONG_TICK_MODEL',actual_mode=observed_mode,metadata_mode=meta.get('model'),
        broker=meta.get('broker_server'),run_id=root.name,legacy_pool_failures=len(pool),
        statistical_track_capacity_hits=int(statistics['track_capacity_hits']),
        read_failures_by_symbol={s['symbol']:int(s['read_failures']) for s in symbols},
        all_final_frontiers_complete=all(s['read_through_msc']==s['requested_to_msc'] and s['root_cause']=='' for s in symbols),
        checks=pd.Series([c['status'] for c in checks]).value_counts().to_dict(),
        model_training_performed=False,holdout_profit_evaluated=False,
        note='Generated-tick labels cannot validate real-tick shock feasibility. Legacy global invalid verdict retained.')
    (out/'provenance_summary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',required=True);p.add_argument('--output',required=True)
    p.add_argument('--journal',action='append',required=True);p.add_argument('--ex5',required=True)
    run(p.parse_args())
