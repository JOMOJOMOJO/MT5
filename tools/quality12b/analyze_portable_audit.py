"""Audit portability engineering runs; no parameter ranking or filter selection."""
import argparse,json,math,re
from collections import Counter
from datetime import datetime
from pathlib import Path
from analyze_cost_channel import ROOT,read,write,save,native,pair,metrics,audit_retry_events
from analyze_reports import number
from compare_reproduction import compare
from tick_quality import audit,execution_blocks

def timestamp(s):return datetime.strptime(s,'%Y.%m.%d %H:%M:%S')
def portfolio_compare(reference,candidate):
    # The legacy HTML parser deliberately assumes one symbol / one open position.
    # Portfolio parity must use position-ID audited deal CSVs instead.
    ha,ma,_=native(reference/'report.htm');hb,mb,_=native(candidate/'report.htm')
    operational={'InpTelemetryFileName','InpIndependentClock','InpDeviationATR'}
    errors=[]
    if {k:v for k,v in ma['inputs'].items() if k not in operational}!={k:v for k,v in mb['inputs'].items() if k not in operational}:errors.append('Signal/risk inputs differ')
    for key in ['broker','currency','symbol','period','initial_deposit','bars','ticks']:
        if ha.get(key)!=hb.get(key):errors.append('Report identity differs: '+key)
    qa=read(reference/'cost.csv',';');qb=read(candidate/'cost.csv',';')
    pair(qa);pair(qb)
    keys=['symbol','entry_kind','type','time_msc','price','volume','sl','tp','profit','commission','swap','fee','reason']
    order=lambda r:(int(r['time_msc']),r['symbol'],r['entry_kind'],r['type'],float(r['price']))
    qa.sort(key=order);qb.sort(key=order);differences=[]
    if len(qa)!=len(qb):errors.append('Deal counts differ')
    for i,(a,b) in enumerate(zip(qa,qb)):
        changed={}
        for key in keys:
            if key=='symbol':equal=a[key]==b[key]
            else:equal=math.isclose(float(a[key]),float(b[key]),rel_tol=0,abs_tol=1e-8)
            if not equal:changed[key]=[a[key],b[key]]
        if changed:differences.append(dict(index=i,fields=changed))
    if differences:errors.append('Execution or cost differs')
    return dict(passed=not errors,classification='EXACT_EXECUTIONS_AND_COSTS' if not errors else 'EXECUTION_DIFFERENCE',
                ignored_execution_inputs=sorted(operational),errors=errors,deal_differences=differences,
                reference_trades=len(pair(qa)),candidate_trades=len(pair(qb)))
def check(run,spec,package):
    h,meta,nd=native(run/'report.htm')
    assert h['broker']=='Vantage Trading Ltd' and h['currency']=='USD'
    assert meta['from_date']==spec['date_from'] and meta['to_date']==spec['date_to']
    expected=dict(line.split('=',1) for line in (run/'inputs.set').read_text().splitlines() if '=' in line)
    assert set(expected)==set(meta['inputs'])
    for k,v in expected.items():
        try:assert float(v)==float(meta['inputs'][k]),k
        except ValueError:assert v.lower()==meta['inputs'][k].lower(),k
    quality=audit(meta,run/'journals')
    assert quality['matching_execution_blocks']==1 and quality['test_finished_in_block']
    block='\n'.join(execution_blocks(meta,run/'journals')[0])
    assert not re.search(r'array out of range|zero divide|DQ_FATAL|DC_FATAL|PC_FATAL|DC_CAUSAL_OR_PARITY_FAILURE',block,re.I)
    result=dict(passed=True,quality=quality)
    if spec['kind']=='harness':
        rows=read(run/'telemetry.csv',';')
        assert len(rows)==18 and len({r['test'] for r in rows})==18
        assert all(r['passed']=='1' for r in rows),rows
        assert not nd and 'PF_QA_FINISH tests=18 errors=0' in block
        result['tests']=18
    else:
        q=read(run/'cost.csv',';');by={r['deal']:r for r in q}
        assert len(by)==len(q) and set(by)=={d['deal'] for d in nd}
        for d in nd:
            r=by[d['deal']];assert r['symbol']==d['symbol']
            for key in ['price','volume','profit','commission','swap']:assert math.isclose(float(r[key]),d[key],abs_tol=1e-7)
        trades=pair(q);write(run/'trades.csv',trades);result['actual']=metrics(trades)
        assert len(trades)==int(number(h['trade_count']))
        assert math.isclose(result['actual']['net'],float(number(h['net_profit'])),abs_tol=0.011)
        if spec['kind']=='daily':
            logs=read(run/'telemetry.csv',';');result['retry_audit']=audit_retry_events(logs)
            assert 'DC_FINISH errors=0 uncertain=0 peak_stop=0' in block
            assert len({(r['symbol'],r['entry_time'][:10]) for r in trades})==len(trades)
            assert set(r['symbol'] for r in logs)==set(expected['InpSymbols'].split(','))
        if spec['expert'] in ['daily_portable','m5_portable']:
            rows=read(run/'risk.csv',';')
            for r in rows:
                assert r['reason'] in ['OK','MIN_VOLUME_EXCEEDS_RISK','INSUFFICIENT_MARGIN'],r
                assert float(r['contract_size'])>0 and float(r['min_volume'])>0
                assert math.isclose(float(r['minimum_equity']),float(r['min_loss'])*100/float(expected['InpRiskPercent']),rel_tol=1e-8)
                if r['reason']=='OK':
                    assert float(r['planned_loss'])<=float(r['budget'])+1e-7
                    assert float(r['volume'])>=float(r['min_volume'])-1e-10
                if r['reason']=='MIN_VOLUME_EXCEEDS_RISK':assert float(r['min_loss'])>float(r['budget']) or float(r['volume'])==0
            result['risk_reasons']=dict(Counter(r['reason'] for r in rows))
            result['risk_reasons_by_symbol']={s:dict(Counter(r['reason'] for r in rows if r['symbol']==s)) for s in sorted({r['symbol'] for r in rows})}
        if spec['expert']=='m5_portable':
            contexts=read(run/'portable_context.csv',';');unknown=0
            for r in contexts:
                assert r['symbol']==spec['symbol']
                if r['history_ready']=='0':unknown+=1;continue
                assert timestamp(r['closed_bar'])<timestamp(r['available_at'])<=timestamp(r['decision'])
                assert timestamp(r['asof'])<=timestamp(r['decision'])
                assert float(r['atr_prior'])>0 and float(r['atr'])>0
                assert math.isclose(float(r['spread_atr']),float(r['spread_price'])/float(r['atr']),abs_tol=1e-7)
                if r['volume_source']=='TICK_ONLY':assert r['real_volume_ratio_prior20']==''
            result['context_rows']=len(contexts);result['context_missing']=unknown
            original=read(run/'context.csv',';')
            for r in contexts:
                if r['history_ready']=='0' or r['tf']=='PERIOD_M5':continue
                peers=[x for x in original if x['stage']=='CANDIDATE' and x['id']==r['id'] and x['tf']==r['tf']]
                assert len(peers)==1
                for a,b in [('legacy_regime','regime'),('legacy_position','position'),('legacy_break_direction','break_direction')]:assert r[a]==peers[0][b],(a,r)
            base=run.parent/f"m5_{spec['symbol']}_reference"/'report.htm'
            parity=compare(base,run/'report.htm',require_real_ticks=False)
            save(run/'execution_parity.json',parity);assert parity['passed'] and parity['classification']=='EXACT_EXECUTIONS_AND_COSTS'
            result['parity']=True
        if spec.get('reference'):
            parity=portfolio_compare((ROOT/spec['reference']).parent,run)
            save(run/'execution_parity.json',parity);assert parity['passed'] and parity['classification']=='EXACT_EXECUTIONS_AND_COSTS'
            result['parity']=True
    save(run/'audit.json',result)
    print(json.dumps(dict(run=spec['run_id'],passed=True,actual=result.get('actual'),tests=result.get('tests'))))

def aggregate(batch,package):
    m=json.loads((package/'manifest.json').read_text(encoding='utf-8'));rows=[]
    for spec in m['runs']:
        a=json.loads((batch/spec['run_id']/'audit.json').read_text(encoding='utf-8'));assert a['passed']
        rows.append(dict(run_id=spec['run_id'],symbol=spec['symbol'],kind=spec['kind'],passed=True,
                         n=a.get('actual',{}).get('n',0),net=a.get('actual',{}).get('net',0),
                         parity=a.get('parity',False),context_rows=a.get('context_rows',0),context_missing=a.get('context_missing',0)))
    write(batch/'statistics.csv',rows)
    # Clock comparison is an execution experiment, not a required equality gate.
    clocks=portfolio_compare(batch/'daily_legacy_clock',batch/'daily_timer')
    save(batch/'clock_comparison.json',clocks)
    lines=['# 複数銘柄汎用化QA','', '固定3か月の工学検証。利益によるパラメータ選抜・本番採用は行っていない。','',
           '|run|銘柄|取引数|損益USD|完全一致比較合格|','|---|---|---:|---:|---|']
    for r in rows:lines.append(f"|{r['run_id']}|{r['symbol']}|{r['n']}|{r['net']:.2f}|{r['parity']}|")
    lines+=['','M5の3銘柄は同銘柄・同設定の変更前後を比較。上位足旧分類も完全一致を監査。',
            '日足の独立timerは時計だけを変えた別実行。差分はclock_comparison.jsonで確認し、利益だけで時計を選ばない。',
            'risk.csvに契約サイズ・最小ロット・最小ロットのSL損失・必要Equity・見送り理由を保存。',
            'portable_context.csvはM5/M15/H1/H4の確定足だけのtick volume比、実出来高欠損、急変/ATR、EMA傾き、旧構造とbreakの観測。売買フィルターではない。',
            '生成tickがある場合、tick volumeは配信・生成モデル依存であり市場の実取引量と解釈しない。']
    (batch/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path);a=p.parse_args()
    if a.run:
        m=json.loads((a.package/'manifest.json').read_text(encoding='utf-8'));check(a.run,next(r for r in m['runs'] if r['run_id']==a.run_id),a.package)
    else:aggregate(a.batch,a.package)
