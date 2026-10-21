"""Separate execution/cash/environment gates without treating swap differences as passes."""
import json,math
from pathlib import Path
from analyze_cost_channel import read,native,pair

OPERATIONAL={'InpTelemetryFileName','InpOperatorCommandFile','InpStatusFileName','InpIndependentClock','InpDeviationATR'}
EXECUTION=['symbol','entry_kind','type','time_msc','price','volume','sl','tp','reason']
CASH=['profit','commission','swap','fee']

def deal_difference(left,right):
    key=lambda r:(int(r['time_msc']),r['symbol'],r['entry_kind'],r['type'],float(r['price']))
    left=sorted(left,key=key);right=sorted(right,key=key)
    execution=[];cash=[]
    for i,(a,b) in enumerate(zip(left,right)):
        for fields,target in [(EXECUTION,execution),(CASH,cash)]:
            diff={}
            for k in fields:
                equal=a[k]==b[k] if k=='symbol' else math.isclose(float(a[k]),float(b[k]),rel_tol=0,abs_tol=1e-8)
                if not equal:diff[k]=[a[k],b[k]]
            if diff:target.append(dict(index=i,fields=diff))
    count_match=len(left)==len(right)
    return dict(execution_pass=count_match and not execution,cash_pass=count_match and not cash,
                reference_deals=len(left),candidate_deals=len(right),execution_differences=execution,cash_differences=cash)

def environment_rows(rows,symbols):
    errors=[];initial={};final={}
    for r in rows:
        if r['phase']=='CHANGE':errors.append('Specification changed during run: '+r['symbol'])
        elif r['phase'] in ('START','END'):
            target=initial if r['phase']=='START' else final
            k=(r['symbol'],r['field'])
            if k in target:errors.append('Duplicate snapshot: '+str(k))
            target[k]=r['value']
        else:errors.append('Unknown snapshot phase')
    if {s for s,k in initial}!=set(symbols) or {s for s,k in final}!=set(symbols):errors.append('Snapshot symbol coverage mismatch')
    required={'account_currency','account_leverage','account_margin_mode','SYMBOL_CURRENCY_BASE','SYMBOL_CURRENCY_PROFIT',
              'SYMBOL_CURRENCY_MARGIN','SYMBOL_TRADE_CALC_MODE','SYMBOL_SWAP_MODE','SYMBOL_SWAP_LONG','SYMBOL_SWAP_SHORT',
              'SYMBOL_TRADE_TICK_SIZE','SYMBOL_TRADE_CONTRACT_SIZE','SYMBOL_VOLUME_MIN','SYMBOL_VOLUME_MAX','SYMBOL_VOLUME_STEP'}
    for s in symbols:
        if not required.issubset({k for symbol,k in initial if symbol==s}):errors.append('Missing required specification: '+s)
    if initial!=final:errors.append('Initial/final specifications differ')
    return dict(passed=not errors,errors=sorted(set(errors)),signature={s:{k:v for (symbol,k),v in sorted(initial.items()) if symbol==s} for s in sorted(symbols)})

def check_environment(run,symbols):
    result=environment_rows(read(run/'environment.csv',';'),symbols)
    history=read(run/'history.csv',';')
    expected={(s,tf) for s in symbols for tf in ['PERIOD_M1','PERIOD_M5','PERIOD_M15','PERIOD_H1','PERIOD_H4','PERIOD_D1']}
    keys={(r['symbol'],r['tf']) for r in history}
    if keys!=expected or len(keys)!=len(history):result['errors'].append('History fingerprint coverage differs')
    if any(int(r['count'])<=0 or int(r['first'])>int(r['last']) for r in history):result['errors'].append('Invalid history fingerprint')
    result['passed']=not result['errors']
    return result

def compare_pair(reference,candidate):
    ha,ma,_=native(reference/'report.htm');hb,mb,_=native(candidate/'report.htm')
    errors=[]
    if {k:v for k,v in ma['inputs'].items() if k not in OPERATIONAL}!={k:v for k,v in mb['inputs'].items() if k not in OPERATIONAL}:errors.append('Trading inputs differ')
    for k in ['broker','currency','symbol','period','initial_deposit','bars','ticks']:
        if ha.get(k)!=hb.get(k):errors.append('Report identity differs: '+k)
    qa=read(reference/'cost.csv',';');qb=read(candidate/'cost.csv',';');pair(qa);pair(qb)
    result=deal_difference(qa,qb)
    symbols=ma['inputs'].get('InpSymbols',ha['symbol']).split(',')
    ea=check_environment(reference,symbols);eb=check_environment(candidate,symbols)
    result['environment_pass']=ea['passed'] and eb['passed'] and ea['signature']==eb['signature']
    result['environment_reference']=ea;result['environment_candidate']=eb
    aa=read(reference/'history.csv',';');bb=read(candidate/'history.csv',';')
    order=lambda r:(r['symbol'],r['tf'])
    result['history_pass']=sorted(aa,key=order)==sorted(bb,key=order)
    if 'InpSymbols' in ma['inputs']:
        keys=['time','symbol','signal_bar','event','price','atr','channel']
        candidates=lambda folder:[{k:r[k] for k in keys} for r in read(folder/'telemetry.csv',';') if r['event']=='SIGNAL']
    else:
        candidates=lambda folder:[r for r in read(folder/'context.csv',';') if r['stage']=='CANDIDATE']
    ca=candidates(reference);cb=candidates(candidate)
    result['candidate_pass']=ca==cb
    result['candidate_rows_reference']=len(ca);result['candidate_rows_candidate']=len(cb)
    for filename in ['runtime_before.json','runtime_after.json']:
        a=json.loads((reference/filename).read_text(encoding='utf-8-sig'))
        b=json.loads((candidate/filename).read_text(encoding='utf-8-sig'))
        if a!=b:errors.append('Runtime differs: '+filename)
    for name,folder in [('Reference',reference),('Candidate',candidate)]:
        before=json.loads((folder/'runtime_before.json').read_text(encoding='utf-8-sig'))
        after=json.loads((folder/'runtime_after.json').read_text(encoding='utf-8-sig'))
        if before!=after:errors.append(name+' runtime changed')
    result['identity_errors']=errors
    result['passed']=not errors and all(result[k] for k in ['execution_pass','cash_pass','environment_pass','history_pass','candidate_pass'])
    result['classification']='EXACT_EXECUTIONS_COSTS_AND_OBSERVED_ENVIRONMENT' if result['passed'] else 'PAIR_INCOMPLETE_OR_DIFFERENT'
    return result
