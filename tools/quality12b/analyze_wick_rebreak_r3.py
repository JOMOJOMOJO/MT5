"""Keep paired environment gates strict; diagnose proven cash-neutral historical swap drift."""
import argparse
import json
from pathlib import Path
from analyze_cost_channel import native, pair, read, save
from analyze_wick_rebreak import aggregate, check
from analyze_wick_rebreak_r2 import history_coverage
from portable_pair_audit import OPERATIONAL, check_environment, deal_difference
from prepare_portable_audit import ROOT, sha, verify


def classify_historical_environment(before, after, inputs, old_deals, new_deals):
    """This exception is for historical comparison only, never current A/B comparisons."""
    changes={}
    for symbol in sorted(set(before)|set(after)):
        a=before.get(symbol,{});b=after.get(symbol,{})
        for field in sorted(set(a)|set(b)):
            if a.get(field)!=b.get(field):
                changes[symbol+'/'+field]=dict(before=a.get(field),after=b.get(field))
    base=dict(environment_exact=not changes,specification_differences=changes)
    if not changes:return dict(base,comparison_usable=True,classification='EXACT_OBSERVED_ENVIRONMENT')
    # No exception for lot/contract/tick size/margin/stop/fill/currency/build/history changes.
    only_swap=all(k.split('/')[-1] in ('SYMBOL_SWAP_LONG','SYMBOL_SWAP_SHORT') for k in changes)
    long_only=inputs.get('InpEnableRoundBucket')=='true' and inputs.get('InpEnableRoundShortBucket')=='false' and all(
        v=='false' for k,v in inputs.items() if k.startswith('InpEnable') and k.endswith('Bucket') and k!='InpEnableRoundBucket')
    deal_check=deal_difference(old_deals,new_deals)
    zero_swap=all(float(r['swap'])==0 for r in old_deals+new_deals)
    trades=pair(old_deals)+pair(new_deals)
    intraday_long=bool(trades) and all(r['side']=='buy' and r['entry_time'][:10]==r['exit_time'][:10] for r in trades)
    usable=only_swap and long_only and zero_swap and intraday_long and deal_check['execution_pass'] and deal_check['cash_pass']
    return dict(base,comparison_usable=usable,classification=(
        'HISTORICAL_SWAP_DRIFT_EXACT_INTRADAY_LONG_EXECUTIONS_AND_CASH' if usable else 'MATERIAL_OR_UNPROVEN_ENVIRONMENT_DRIFT'),
        evidence=dict(only_swap_fields=only_swap,long_only_inputs=long_only,zero_applied_swap=zero_swap,
                      all_trades_intraday_long=intraday_long,executions_exact=deal_check['execution_pass'],cash_exact=deal_check['cash_pass']))


def historical_parity(old,new):
    ha,ma,_=native(old/'report.htm');hb,mb,_=native(new/'report.htm')
    assert {k:v for k,v in ma['inputs'].items() if k not in OPERATIONAL}=={k:v for k,v in mb['inputs'].items() if k not in OPERATIONAL}
    for k in ['broker','currency','symbol','period','initial_deposit','bars','ticks']:
        assert ha[k]==hb[k],('Observer repair changed report identity',k)
    runtime=[json.loads((p/n).read_text(encoding='utf-8-sig')) for p in [old,new] for n in ['runtime_before.json','runtime_after.json']]
    assert all(r==runtime[0] for r in runtime),'Runtime drift since original test'
    a=check_environment(old,[ha['symbol']]);b=check_environment(new,[hb['symbol']])
    qa=read(old/'cost.csv',';');qb=read(new/'cost.csv',';')
    environment=classify_historical_environment(a['signature'],b['signature'],mb['inputs'],qa,qb)
    # Save the difference even if this comparison is rejected.
    save(new/'historical_environment_comparison.json',environment)
    assert environment['comparison_usable'],environment
    result=deal_difference(qa,qb)
    assert result['execution_pass'] and result['cash_pass'],'Observer repair changed executions/cash'
    checked=[]
    for name in ['risk.csv','adjustment.csv','funnel.csv','rb_candidates.csv','rb_events.csv',
                 'rb_entries.csv','rb_outcomes.csv','rb_context.csv','rb_execution.csv','rb_bars.csv']:
        if not (old/name).exists():continue
        assert sha(old/name)==sha(new/name),('Observer repair changed decision artifact',name)
        checked.append(name)
    return dict(result,passed=True,decision_artifacts_exact=checked,environment=environment,
                old_history_not_accepted=True,scope='Exact trading outputs; environment equality separately reported, never inferred')


def check_run(run,spec,package,manifest):
    try:
        if spec['kind']!='harness':
            env=read(run/'environment.csv',';')
            stamps=lambda phase:{int(r['observed_time']) for r in env if r['phase']==phase}
            coverage=history_coverage(read(run/'history.csv',';'),spec,stamps('START'),stamps('END'))
            h,_,_=native(run/'report.htm')
            m5=[r for r in coverage['rows'] if r['tf']=='PERIOD_M5']
            if len(m5)!=1 or int(m5[0].get('test_count','0'))!=int(h['bars']):
                coverage['passed']=False;coverage['errors'].append('M5 count differs from native tester bars')
            save(run/'history_period_audit.json',coverage);assert coverage['passed'],coverage['errors']
        # Includes STRICT current-run specification stability and full current A/B equality.
        check(run,spec,package)
        old=ROOT/manifest['previous_batch']/spec['run_id']
        if spec['kind']!='harness' and (old/'report.htm').exists():
            save(run/'observer_repair_parity.json',historical_parity(old,run))
        result=json.loads((run/'audit.json').read_text());result.pop('r2_error',None)
        result['r3_audit_passed']=True;save(run/'audit.json',result)
        print(json.dumps(dict(run=spec['run_id'],r3_all_gates_passed=True)))
    except Exception as error:
        path=run/'audit.json';result=json.loads(path.read_text()) if path.exists() else {}
        result.update(passed=False,r3_error=str(error));save(path,result);raise


def finish(batch,package,manifest):
    differences=[]
    for spec in manifest['runs']:
        folder=batch/spec['run_id'];a=json.loads((folder/'audit.json').read_text())
        assert a['passed'] and a['r3_audit_passed']
        if spec['kind']=='harness':continue
        assert json.loads((folder/'history_period_audit.json').read_text())['passed']
        if (ROOT/manifest['previous_batch']/spec['run_id']/'report.htm').exists():
            p=json.loads((folder/'observer_repair_parity.json').read_text());assert p['passed']
            if not p['environment']['environment_exact']:
                differences.append(dict(run_id=spec['run_id'],**p['environment']))
    aggregate(batch,package)
    save(batch/'historical_environment_differences.json',differences)
    with (batch/'summary.md').open('a',encoding='utf-8') as f:
        f.write('\n## 検証の継続と環境差\n\n修正後のr2からharnessと完結済みUSDJPY短期reference/A/Bの4本をhash検証付きで再利用し、30本を新規実行。'
                '元の壊れた履歴fingerprintは再利用しない。対象年・全月・6時間足の履歴監査を維持。'
                '現行A/Bペアの環境仕様・履歴・候補一致は厳格に照合。'
                '過去runとのswap仕様差は別ファイルに全件記録。過去環境と同一とは主張しない。'
                '例外はswap値だけの差で、両方の全取引が買い・同一サーバー日内完結・適用swapゼロ、約定/現金損益/意思決定CSVが完全一致した場合のみ。'
                'ロット・契約・spread・時刻・SL/TP・損益の差を許容する処理はない。\n')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True)
    p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path)
    a=p.parse_args();m=verify(a.package)
    if a.run:check_run(a.run,next(s for s in m['runs'] if s['run_id']==a.run_id),a.package,m)
    else:finish(a.batch,a.package,m)
