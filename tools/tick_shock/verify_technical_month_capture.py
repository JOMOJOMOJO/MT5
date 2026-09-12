"""Fail-closed monthly research capture checks; no model fitting or profit analysis."""
import argparse,csv,json,re,hashlib,shutil
from pathlib import Path

def values(row):
    return dict(x.split('=',1) for x in row.get('value','').split(';') if '=' in x)

def technical_integrity(rows):
    def one(kind):
        found=[r for r in rows if r.get('record_type')==kind]
        return values(found[0]) if len(found)==1 else {}
    integrity=one('INTEGRITY');stat=one('STATISTICAL_CLUSTER');control=one('MATCHED_CONTROL')
    symbols=[values(r) for r in rows if r.get('record_type')=='SYMBOL']
    return {
        'global_tick_loss_zero':all(integrity.get(k)=='0' for k in ('pending_capacity_hits','dropped_ticks','cursor_stalls')),
        'global_frontier_complete':integrity.get('incomplete_frontier')=='false' and integrity.get('root_cause')=='',
        'symbol_readthrough_complete':len(symbols)==6 and all(s.get('read_through_msc')==s.get('requested_to_msc') and int(s.get('read_through_msc','0'))>0 and s.get('history_synchronized')=='true' and s.get('root_cause')=='' and all(s.get(k)=='0' for k in ('cursor_stalls','page_limits','last_copy_error')) for s in symbols),
        'statistical_track_capacity_zero':stat.get('track_capacity_hits')=='0',
        'control_loss_zero':control.get('capacity_hits')=='0' and control.get('drops')=='0',
        'known_run_status':integrity.get('validation')=='VALIDATED' or (integrity.get('validation')=='VALIDATION_INVALID' and int(integrity.get('event_pool_exhaustions','0'))>0),
    },integrity

def read(p):
    raw=p.read_bytes()
    return raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig',errors='replace')

def verify(common,run,data_root):
    rid=common.name;prefix=f'ExpectedValue_MultiCurrency_TickShockResearch_{rid}_'
    checks={};evidence=[];endings=[];counters={};integrity={}
    # Restrict journal search to the selected terminal's local agent root.
    agent_root=data_root.parents[1]/'Tester'/data_root.name
    logs=sorted(agent_root.glob('Agent-*/logs/*.log'),key=lambda p:p.stat().st_mtime,reverse=True)
    block=None
    for log in logs[:64]:
        lines=read(log).splitlines()
        found=[i for i,s in enumerate(lines) if s.rstrip().endswith('InpRunId='+rid)]
        if not found:continue
        idx=found[-1]
        start=next((i for i in range(idx-1,-1,-1) if 'started with inputs:' in lines[i]),None)
        if start is None:continue
        end=next((i for i in range(idx+1,len(lines)) if 'started with inputs:' in lines[i]),len(lines))
        block=lines[max(0,start-8):end]
        # Cross midnight only if this run has not finished; never append another run.
        if not any('Test passed in ' in s for s in block):
            for later in sorted(log.parent.glob('*.log')):
                if later.name<=log.name:continue
                continuation=read(later).splitlines()
                end=next((i for i,s in enumerate(continuation) if 'started with inputs:' in s),len(continuation))
                block.extend(continuation[:end])
                if any('Test passed in ' in s for s in block) or end<len(continuation):break
        break
    checks['matching_journal']=block is not None
    if block:
        checks['real_tick_mode']=any('generating based on real ticks' in s for s in block) and not any('every tick generating' in s for s in block)
        checks['tester_completed']=any('Test passed in ' in s for s in block)
        endings=[s for s in block if 'technical_discovery episodes=' in s]
        checks['technical_end_summary']=len(endings)==1
        if len(endings)==1:
            counters=dict(re.findall(r'(episodes|capacity|feature_invalid|orders)=(\d+)',endings[0]))
            checks['technical_no_loss']=counters.get('capacity')=='0' and counters.get('feature_invalid')=='0'
            checks['research_no_orders']=counters.get('orders')=='0'
        checks['broker_bybit']=any('(Bybit-Live)' in s for s in block)
        evidence=[s for s in block if any(k in s for k in ('InpRunId=','started with inputs:','generating based on real ticks','every tick generating','technical_discovery episodes=','Test passed in ','real ticks discarded','initialized research_only','validation invalid:'))]
    (run/'tester_journal_excerpt.txt').write_text('\n'.join(evidence)+'\n',encoding='utf-8')
    summary=common/(prefix+'summary.csv')
    checks['summary_exists']=summary.exists()
    if summary.exists():
        rows=list(csv.DictReader(read(summary).splitlines()))
        scoped,integrity=technical_integrity(rows)
        checks.update(scoped)
        checks['six_symbols']=len({r['key'] for r in rows if r['record_type']=='SYMBOL'})==6
    for name in ('technical_features.csv','technical_outcomes.csv'):
        p=common/name;checks[name+'_exists']=p.exists() and p.stat().st_size>100
    if all(checks.get(x,False) for x in ('technical_features.csv_exists','technical_outcomes.csv_exists')):
        with (common/'technical_features.csv').open(encoding='utf-8-sig',newline='') as f:features=list(csv.DictReader(f))
        with (common/'technical_outcomes.csv').open(encoding='utf-8-sig',newline='') as f:outcomes=list(csv.DictReader(f))
        ids={r['episode_id'] for r in features};keys={(r['episode_id'],r['direction'],r['distance_index']) for r in outcomes}
        checks['episode_rows_unique']=len(ids)==len(features)
        checks['outcome_rows_unique']=len(keys)==len(outcomes)
        checks['outcomes_twelve_per_episode']=len(keys)==len(ids)*12 and {r['episode_id'] for r in outcomes}==ids
        checks['no_feature_future']=all(int(r['feature_future_count'])==0 and int(r['feature_max_close_msc'])<=int(r['t0_msc']) for r in features)
        checks['episode_counter_matches']=len(endings)==1 and int(counters.get('episodes','-1'))==len(features)
        geometry_keys={eid:set() for eid in ids}
        for r in outcomes:geometry_keys.setdefault(r['episode_id'],set()).add((r['direction'],r['distance_index']))
        checks['exact_geometry_keys']=set(geometry_keys)==ids and all(g=={(str(d),str(i)) for d in (1,-1) for i in range(6)} for g in geometry_keys.values())
        feature_map={r['episode_id']:r for r in features}
        checks['identity_clocks_match']=all(r['symbol']==feature_map[r['episode_id']]['symbol'] and r['market_cluster_id']==feature_map[r['episode_id']]['market_cluster_id'] and r['t0_msc']==feature_map[r['episode_id']]['t0_msc'] and r['signal_processing_msc']==feature_map[r['episode_id']]['t0_processing_msc'] for r in outcomes)
        entries=[r for r in outcomes if float(r['entry_msc'] or 0)>0]
        checks['causal_entry']=all(float(r['entry_msc'])>=max(float(r['signal_processing_msc']),float(r['entry_eligible_msc'])) and float(r['entry_msc'])>max(float(r['t0_msc']),float(r['source_quote_msc'])) for r in entries)
        checks['causal_exit']=all(float(r['exit_msc'])>=float(r['entry_msc']) for r in outcomes if r['status'] in ('TP','SL','TIME','TIMEOUT'))
        episode_file=common/(prefix+'medium_horizon_episode_summary.csv')
        checks['episode_population_matches']=episode_file.exists() and {r['episode_id'] for r in csv.DictReader(read(episode_file).splitlines())}==ids
    # Preserve small evidence and primary data; huge legacy CSV stays only in Common.
    names=['technical_features.csv','technical_outcomes.csv']+[prefix+x for x in ('summary.csv','summary.csv.runmeta','symbol_specs.csv','medium_horizon_episode_summary.csv')]
    for name in names:
        p=common/name
        if p.exists():shutil.copy2(p,run/(name[len(prefix):] if name.startswith(prefix) else name))
    legacy=summary.exists() and integrity.get('validation')=='VALIDATION_INVALID'
    result={'status':('PASS_WITH_LEGACY_WARNING' if legacy else 'PASS') if checks and all(checks.values()) else 'FAIL','checks':checks,'common_path':str(common),'run_id':rid,'commission':'NOT_OBSERVED','generated_fallback_minutes':'NOT_QUANTIFIED','scope':'TECHNICAL_COLLECTION_ONLY','legacy_run_integrity':integrity if summary.exists() else {},'input_sha256':{name:hashlib.sha256((common/name).read_bytes()).hexdigest() for name in ('technical_features.csv','technical_outcomes.csv') if (common/name).exists()},'note':'User-authorized scoped collection gate. Legacy run remains INVALID; only Technical data collection accepted. No ML or P/L evaluation; real-tick mode does not prove zero generated fallback.'}
    (run/'collection_qa.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))
    return 0 if result['status'] in ('PASS','PASS_WITH_LEGACY_WARNING') else 2

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--common',type=Path,required=True);p.add_argument('--run',type=Path,required=True);p.add_argument('--data-root',type=Path,required=True)
    a=p.parse_args();raise SystemExit(verify(a.common,a.run,a.data_root))
