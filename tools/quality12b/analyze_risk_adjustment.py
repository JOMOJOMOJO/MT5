"""Risk-budget safety, OFF parity, and causal attribution of an opt-in size repair."""
import argparse,json,math,re
from pathlib import Path
from analyze_cost_channel import read,save,write,native
from analyze_portable_audit_r5 import check_r5,timestamp
from portable_risk_audit import audit_risk,minute_key
from portable_pair_audit import OPERATIONAL,deal_difference,check_environment
from tick_quality import audit,execution_blocks


def audit_adjustments(rows,risk,enabled):
    assert len(rows)==len(risk),'Adjustment/risk log coverage'
    recovered=[]
    for a,r in zip(rows,risk):
        assert a['time']==r['time'] and a['symbol']==r['symbol'] and a['side']==r['side']
        assert int(a['enabled'])==int(enabled)
        assert a['after_reason']==r['reason']
        for x,y in [('entry','entry'),('sl','sl'),('budget','budget'),('after_volume','volume'),('after_loss','planned_loss'),('margin','margin')]:
            assert math.isclose(float(a[x]),float(r[y]),rel_tol=0,abs_tol=1e-7),(x,a,r)
        before=float(a['before_volume']);after=float(a['after_volume']);loss=float(a['after_loss']);budget=float(a['budget']);checks=int(a['checks'])
        assert all(math.isfinite(float(a[k])) for k in ['before_volume','before_loss','after_volume','after_loss','budget'])
        assert 0<=checks<=32
        if checks:
            assert enabled and a['before_reason']=='NORMALIZED_VOLUME_EXCEEDS_RISK'
            assert float(a['before_loss'])>budget+1e-7
            assert 0<after<before-1e-10,'Adjustment must reduce volume'
            assert float(a['min_volume'])-1e-10<=after<=float(a['max_volume'])+1e-10
            assert abs(after/float(a['step'])-round(after/float(a['step'])))<1e-7
            if a['after_reason']=='OK':
                assert 0<loss<=budget+1e-7
                recovered.append(a)
        else:
            assert a['before_reason']==a['after_reason']
            assert before==after and float(a['before_loss'])==loss
        if not enabled:assert checks==0
    return recovered


def pair_environment(base,run):
    ha,ma,_=native(base/'report.htm');hb,mb,_=native(run/'report.htm')
    ignore=OPERATIONAL|{'InpAdjustRoundedVolume'}
    assert {k:v for k,v in ma['inputs'].items() if k not in ignore}=={k:v for k,v in mb['inputs'].items() if k not in ignore}
    for k in ['broker','currency','symbol','period','initial_deposit','bars','ticks']:assert ha[k]==hb[k],k
    ea=check_environment(base,[ha['symbol']]);eb=check_environment(run,[hb['symbol']])
    assert ea['passed'] and eb['passed'] and ea['signature']==eb['signature']
    key=lambda r:(r['symbol'],r['tf'])
    assert sorted(read(base/'history.csv',';'),key=key)==sorted(read(run/'history.csv',';'),key=key)
    snapshots=[]
    for folder in [base,run]:
        for name in ['runtime_before.json','runtime_after.json']:snapshots.append(json.loads((folder/name).read_text(encoding='utf-8-sig')))
    assert all(x==snapshots[0] for x in snapshots)
    cols=['time','signal','signal_reason','spread_atr','spread_allowed','atr']
    signals=lambda d:[{k:r[k] for k in cols} for r in read(d/'funnel.csv',';')]
    assert signals(base)==signals(run),'Underlying bar signals changed'
    return dict(environment_pass=True,history_pass=True,runtime_pass=True,input_pass=True,signal_pass=True)


def entry_plan_coverage(deals,risk):
    for d in deals:
        if int(d['entry_kind'])!=0:continue
        plans=[r for r in risk if r['symbol']==d['symbol'] and r['reason']=='OK' and minute_key(r['time'])==int(d['time_msc'])//60000]
        assert len(plans)==1,('Entry plan coverage',d)
        p=plans[0]
        assert math.isclose(float(p['volume']),float(d['volume']),rel_tol=0,abs_tol=1e-8)
        assert math.isclose(float(p['sl']),float(d['sl']),rel_tol=0,abs_tol=1e-8)
        assert float(p['planned_loss'])<=float(p['budget'])+1e-7


def attributable_difference(left,right,recovered):
    comparison=deal_difference(left,right)
    if comparison['execution_pass'] and comparison['cash_pass']:
        return dict(comparison,classification='NO_EXECUTION_CHANGE',prefix_verified=True)
    entries=[d for d in right if int(d['entry_kind'])==0 and any(r['symbol']==d['symbol'] and minute_key(r['time'])==int(d['time_msc'])//60000 for r in recovered)]
    assert entries,'Trade change without an accepted adjusted entry'
    first=min(int(d['time_msc']) for d in entries)
    prefix=deal_difference([d for d in left if int(d['time_msc'])<first],[d for d in right if int(d['time_msc'])<first])
    assert prefix['execution_pass'] and prefix['cash_pass'],'Trades changed before the first adjustment'
    return dict(comparison,classification='FIRST_CHANGE_FOLLOWS_ADJUSTED_ENTRY',first_adjusted_entry_msc=first,
                recovered_entries=len(entries),prefix_verified=True,
                limitation='Subsequent equity/position state can change later volume and eligibility; not every changed trade is a new signal')


def check(run,spec,package):
    h,meta,nd=native(run/'report.htm')
    assert meta['from_date']==spec['date_from'] and meta['to_date']==spec['date_to']
    expected=dict(line.split('=',1) for line in (run/'inputs.set').read_text().splitlines() if '=' in line)
    assert meta['inputs']==expected
    frozen=json.loads((package/'frozen'/spec['inputs']).read_text(encoding='utf-8'))
    assert {k:v for k,v in expected.items() if k not in OPERATIONAL}=={k:v for k,v in frozen.items() if k not in OPERATIONAL}
    if spec['kind']=='harness':
        q=audit(meta,run/'journals');blocks=execution_blocks(meta,run/'journals')
        assert q['matching_execution_blocks']==1 and q['test_finished_in_block']
        block='\n'.join(blocks[0]);assert 'PFA_QA_FINISH tests=16 errors=0' in block
        assert not re.search(r'array out of range|zero divide',block,re.I)
        rows=read(run/'telemetry.csv',';')
        assert len(rows)==16 and len({r['test'] for r in rows})==16 and all(r['passed']=='1' for r in rows) and not nd
        save(run/'audit.json',dict(passed=True,tests=16,quality=q))
        print(json.dumps(dict(run=spec['run_id'],passed=True,tests=16)));return
    # Generic native/deal/clock/environment gates, with intervention-aware parity below.
    proxy=dict(spec,expert='risk_adjustment_adapter')
    check_r5(run,proxy,package)
    result=json.loads((run/'audit.json').read_text(encoding='utf-8'))
    deals=read(run/'cost.csv',';');risk=read(run/'risk.csv',';')
    result.update(audit_risk(risk,deals,float(expected['InpRiskPercent'])))
    entry_plan_coverage(deals,risk)
    contexts=read(run/'portable_context.csv',';')
    for r in contexts:
        assert r['history_ready']=='1' and r['symbol']==spec['symbol']
        assert timestamp(r['closed_bar'])<timestamp(r['available_at'])<=timestamp(r['decision'])
        assert timestamp(r['asof'])<=timestamp(r['decision']) and float(r['atr_prior'])>0
    result.update(context_rows=len(contexts),context_missing=0)
    recovered=[]
    if spec['mode']!='legacy':
        recovered=audit_adjustments(read(run/'adjustment.csv',';'),risk,spec['mode']=='on')
        save(run/'recovered_plans.json',recovered);result['recovered_plans']=len(recovered)
    if spec['mode']=='off':
        base=run.parent/(spec['symbol']+'_legacy');env=pair_environment(base,run)
        diff=deal_difference(read(base/'cost.csv',';'),deals)
        assert diff['execution_pass'] and diff['cash_pass'],diff
        assert read(base/'risk.csv',';')==risk,'OFF risk plans differ'
        assert read(base/'portable_context.csv',';')==contexts
        save(run/'off_parity.json',dict(env,**diff,passed=True))
    if spec['mode']=='on':
        base=run.parent/(spec['symbol']+'_off');env=pair_environment(base,run)
        diff=attributable_difference(read(base/'cost.csv',';'),deals,recovered)
        save(run/'intervention.json',dict(env,**diff,passed=True))
    save(run/'audit.json',result)
    print(json.dumps(dict(run=spec['run_id'],passed=True,recovered_plans=len(recovered),actual=result['actual'])))


def aggregate(batch,package):
    manifest=json.loads((package/'manifest.json').read_text(encoding='utf-8'));rows=[]
    for s in manifest['runs']:
        a=json.loads((batch/s['run_id']/'audit.json').read_text(encoding='utf-8'));assert a['passed']
        if s['kind']=='harness':continue
        rows.append(dict(run=s['run_id'],symbol=s['symbol'],mode=s['mode'],**a['actual'],recovered_plans=a.get('recovered_plans',0)))
    write(batch/'results.csv',rows)
    lines=['# ロット切下げ再計算の単独検証','','全run監査合格。利益に基づく選択・本番採用は未実施。','',
           '|銘柄|mode|件数|損益USD|PF|調整後受理plan|','|---|---|---:|---:|---:|---:|']
    for r in rows:lines.append(f"|{r['symbol']}|{r['mode']}|{r['n']}|{r['net']:.2f}|{r['pf']:.4f}|{r['recovered_plans']}|")
    lines+=['','OFFは旧版と売買・risk.csv・環境診断一致を要求。ONは予定損失予算内、volume切下げ、実発注とplanの対応を要求。',
            'ONで追加entry後は保有・Equityが変わるため後続注文のlotや可否も変わり得る。差分はintervention.jsonに保存。',
            '既知2023年1〜3月、履歴品質は各audit.jsonで確認。長期/OOS/デモ検証ではない。']
    (batch/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path);a=p.parse_args()
    m=json.loads((a.package/'manifest.json').read_text(encoding='utf-8'))
    if a.run:check(a.run,next(r for r in m['runs'] if r['run_id']==a.run_id),a.package)
    else:aggregate(a.batch,a.package)
