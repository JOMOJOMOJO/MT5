"""All original gates plus coverage of the actual test year and observer parity."""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from analyze_cost_channel import native, read, save
from analyze_wick_rebreak import check, aggregate
from portable_pair_audit import OPERATIONAL, check_environment, deal_difference
from prepare_portable_audit import ROOT, sha, verify

TFS = ['PERIOD_M1','PERIOD_M5','PERIOD_M15','PERIOD_H1','PERIOD_H4','PERIOD_D1']


def epoch(value):
    return int(datetime.strptime(value,'%Y.%m.%d').replace(tzinfo=timezone.utc).timestamp())


def expected_months(start, end):
    cursor = datetime.fromtimestamp(start,timezone.utc).replace(day=1)
    stop = datetime.fromtimestamp(end,timezone.utc)
    months=[]
    while cursor < stop:
        months.append(cursor.strftime('%Y%m'))
        cursor=cursor.replace(year=cursor.year+1,month=1) if cursor.month==12 else cursor.replace(month=cursor.month+1)
    return months


def history_coverage(rows, spec, start_stamps, end_stamps):
    begin=epoch(spec['date_from']);finish=epoch(spec['date_to'])
    warmup=datetime.fromtimestamp(begin,timezone.utc).replace(year=int(spec['date_from'][:4])-1,month=1,day=1)
    warmup=int(warmup.timestamp())
    errors=[]
    if len(rows)!=6 or {(r['symbol'],r['tf']) for r in rows}!={(spec['symbol'],tf) for tf in TFS}:
        errors.append('Missing or duplicated timeframe')
    if start_stamps!={begin}:errors.append('Observer start differs from tester start')
    if len(end_stamps)!=1 or any(not begin<=t<finish for t in end_stamps):
        errors.append('Observer end outside tester interval')
    months=expected_months(begin,finish)
    for r in rows:
        label=r['symbol']+'/'+r['tf']
        required=['test_start','test_end','test_count','test_first','test_last','test_months']
        if not all(k in r for k in required):
            errors.append(label+': legacy or incomplete fingerprint schema');continue
        if int(r['from'])!=warmup or int(r['test_start'])!=begin:
            errors.append(label+': requested interval differs')
        if {int(r['to'])}!=end_stamps or {int(r['test_end'])}!=end_stamps:
            errors.append(label+': end differs from final observation')
        if not warmup<=int(r['first'])<=begin-180*86400:
            errors.append(label+': inadequate warm-up coverage')
        if not 0<int(r['test_count'])<=int(r['count']):
            errors.append(label+': no test-period bars')
        if not begin<=int(r['test_first'])<=begin+7*86400:
            errors.append(label+': missing test opening week')
        if not finish-7*86400<=int(r['test_last'])<=int(r['last'])<=int(r['to'])<finish:
            errors.append(label+': missing test ending week or future bars')
        if r['test_months'].split(',')!=months:
            errors.append(label+': missing or extra test month')
    return dict(passed=not errors,errors=errors,required_months=months,rows=rows,
                scope='Full observed OHLC/volume/spread and warm-up; not a hash of every generated tick')


def historical_parity(old, new):
    ha,ma,_=native(old/'report.htm');hb,mb,_=native(new/'report.htm')
    assert {k:v for k,v in ma['inputs'].items() if k not in OPERATIONAL}=={k:v for k,v in mb['inputs'].items() if k not in OPERATIONAL}
    for k in ['broker','currency','symbol','period','initial_deposit','bars','ticks']:
        assert ha[k]==hb[k],('Observer repair changed report identity',k)
    runtime=[json.loads((p/n).read_text(encoding='utf-8-sig')) for p in [old,new] for n in ['runtime_before.json','runtime_after.json']]
    assert all(r==runtime[0] for r in runtime),'Runtime drift since original test'
    assert check_environment(old,[ha['symbol']])['signature']==check_environment(new,[hb['symbol']])['signature'],'Observed specification drift'
    result=deal_difference(read(old/'cost.csv',';'),read(new/'cost.csv',';'))
    assert result['execution_pass'] and result['cash_pass'],'Observer repair changed executions/cash'
    names=['risk.csv','adjustment.csv','funnel.csv','rb_candidates.csv','rb_events.csv',
           'rb_entries.csv','rb_outcomes.csv','rb_context.csv','rb_execution.csv','rb_bars.csv']
    checked=[]
    for name in names:
        if not (old/name).exists():continue
        assert sha(old/name)==sha(new/name),('Observer repair changed decision artifact',name)
        checked.append(name)
    return dict(result,passed=True,decision_artifacts_exact=checked,
                old_history_not_accepted=True,old_history_role='Known wrong requested dates; never reused as coverage evidence')


def check_run(run,spec,package,manifest):
    try:
        if spec['kind']!='harness':
            env=read(run/'environment.csv',';')
            stamps=lambda phase:{int(r['observed_time']) for r in env if r['phase']==phase}
            coverage=history_coverage(read(run/'history.csv',';'),spec,stamps('START'),stamps('END'))
            report,_,_=native(run/'report.htm')
            m5=[r for r in coverage['rows'] if r['tf']=='PERIOD_M5']
            if len(m5)!=1 or int(m5[0].get('test_count','0'))!=int(report['bars']):
                coverage['errors'].append('M5 test-period count differs from native tester bars')
                coverage['passed']=False
            save(run/'history_period_audit.json',coverage);assert coverage['passed'],coverage['errors']
        check(run,spec,package)
        old=ROOT/manifest['previous_batch']/spec['run_id']
        if spec['kind']!='harness' and (old/'report.htm').exists():
            proof=historical_parity(old,run);save(run/'observer_repair_parity.json',proof)
    except Exception as error:
        path=run/'audit.json'
        result=json.loads(path.read_text()) if path.exists() else {}
        result.update(passed=False,r2_error=str(error));save(path,result)
        raise


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True)
    p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path)
    a=p.parse_args();m=verify(a.package)
    if a.run:
        check_run(a.run,next(s for s in m['runs'] if s['run_id']==a.run_id),a.package,m)
    else:
        for spec in m['runs']:
            if spec['kind']=='harness':continue
            folder=a.batch/spec['run_id']
            assert json.loads((folder/'history_period_audit.json').read_text())['passed']
            if (ROOT/m['previous_batch']/spec['run_id']/'report.htm').exists():
                assert json.loads((folder/'observer_repair_parity.json').read_text())['passed']
        aggregate(a.batch,a.package)
        with (a.batch/'summary.md').open('a',encoding='utf-8') as f:
            f.write('\n## 履歴監査修正 r2\n\n全34本を新規実行。旧期間の結果をコピーして合格扱いにはしていない。'
                    '前年のウォームアップから各テスト最終観測時刻までの6時間足を照合し、対象年の全月を必須とした。'
                    '旧版で実行済みの23本中、harnessを除く22本は約定・損益・意思決定CSVの変更前後一致も確認した。'
                    '修正は研究用履歴観測のみ。戦略、売買パラメータ、本番EAは変更なし。\n')
