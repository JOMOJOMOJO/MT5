"""Causal two-arm cohort checks and descriptive, non-optimized entry comparison."""
import argparse,json,math,re
from bisect import bisect_left,bisect_right
from collections import Counter,defaultdict
from datetime import datetime,timezone
from pathlib import Path
import numpy as np
from analyze_cost_channel import read,write,save,native,metrics
from analyze_portable_audit_r5 import check_r5,timestamp
from analyze_risk_adjustment import entry_plan_coverage,audit_adjustments
from portable_risk_audit import audit_risk
from portable_pair_audit import OPERATIONAL,deal_difference,check_environment
from tick_quality import audit,execution_blocks


def ms(value):return int(datetime.strptime(value,'%Y.%m.%d %H:%M:%S').replace(tzinfo=timezone.utc).timestamp()*1000)
def close(a,b):return math.isclose(float(a),float(b),rel_tol=0,abs_tol=1e-7)
def keyed(rows,keys):
    result={tuple(r[k] for k in keys):r for r in rows}
    assert len(rows)==len(result),('Duplicate keys',keys)
    return result


def check_cohort(candidates,events,entries,outcomes,bars,contexts):
    c=keyed(candidates,['id']);e=keyed(entries,['id','arm']);o=keyed(outcomes,['id','arm'])
    b=keyed(bars,['bar_time']);ev=keyed(events,['id'])
    bar_times=[ms(r['bar_time']) for r in bars]
    assert bar_times==sorted(bar_times)
    for row in bars:
        assert ms(row['bar_time'])+300000<=ms(row['available_at'])<=int(row['observed_msc'])<ms(row['available_at'])+1000
    assert set(c)==set(ev) and set(e)==set(o)
    assert {k[0] for k in e if k[1]=='A'}=={k[0] for k in c}
    assert all(k[1] in ('A','B') for k in e)
    assert len(contexts)==3*len(entries)
    ctx=keyed(contexts,['id','arm','tf'])
    for (id,),row in c.items():
        assert ms(row['signal_bar'])+300000<=ms(row['available_at'])
        assert ms(row['anchor_bar'])<ms(row['anchor_confirmed'])<=ms(row['available_at'])
        assert ms(row['high_bar'])<ms(row['high_confirmed'])<=ms(row['available_at'])
        assert close(row['high'],b[(row['signal_bar'],)]['high'])
        a=e[id,'A'];assert ms(row['available_at'])<=int(a['time_msc'])<ms(row['available_at'])+1000
        assert a['time_msc']==b[row['signal_bar'],]['observed_msc']
        event=ev[id,];assert close(event['fixed_high'],row['high']) and close(event['anchor_low'],row['anchor_low'])
        assert int(event['time_msc'])>=int(a['time_msc'])
        if event['event']=='B_TRIGGER':
            assert (id,'B') in e
            assert 1<=int(event['age_bars'])<=18
            assert ms(event['closed_bar'])>ms(row['signal_bar'])
            assert ms(event['closed_bar'])+300000<=int(event['time_msc'])
            assert float(event['closed_price'])>float(row['high'])
            assert close(event['closed_price'],b[event['closed_bar'],]['close'])
            assert event['time_msc']==b[event['closed_bar'],]['observed_msc']
            assert e[id,'B']['time_msc']==event['time_msc']
            prior=bars[bisect_right(bar_times,ms(row['signal_bar'])):bisect_left(bar_times,ms(event['closed_bar']))]
            assert all(float(r['close'])<=float(row['high']) for r in prior),'Missed earlier closed breakout'
        else:
            assert (id,'B') not in e
            assert event['event'] in ('PARENT_LOW_BROKEN','EXPIRED','END_CENSORED')
            if event['event']=='PARENT_LOW_BROKEN':assert float(event['bid'])<float(row['anchor_low'])
            if event['event']=='EXPIRED':assert int(event['age_bars'])>=18
    for k,entry in e.items():
        result=o[k];assert entry['time_msc']==result['entry_msc']
        assert int(result['entry_msc'])<=int(result['exit_msc'])
        for x,y in [('ask','entry'),('sl','sl'),('tp','tp')]:assert close(entry[x],result[y])
        assert float(entry['sl'])<float(entry['ask'])<float(entry['tp'])
        assert close(entry['risk'],float(entry['ask'])-float(entry['sl']))
        assert close(result['result_r'],(float(result['exit_price'])-float(entry['ask']))/float(entry['risk']))
        assert float(result['mfe_r'])>=0 and float(result['mae_r'])>=0
        assert result['outcome'] in ('SL','TP','TIME_EXIT','END_CENSORED')
        if result['outcome']=='TP':assert float(result['exit_price'])>=float(result['tp'])
        if result['outcome']=='SL':assert float(result['exit_price'])<=float(result['sl'])
        for tf in ['PERIOD_M15','PERIOD_H1','PERIOD_H4']:
            context=ctx[*k,tf]
            assert ms(context['decision'])<=int(entry['time_msc'])<ms(context['decision'])+1000
            assert ms(context['asof'])<=ms(context['decision']) and ms(context['break_confirmed'])<=ms(context['decision'])
    return dict(candidates=len(c),b_triggers=sum(r['event']=='B_TRIGGER' for r in events),
                terminal_reasons=dict(Counter(r['event'] for r in events)),shadows=len(e),
                ambiguous=sum(r['ambiguous_exit_minute']=='1' for r in outcomes),
                censored=sum(r['outcome']=='END_CENSORED' for r in outcomes))


def market_pair(base,run):
    ha,ma,_=native(base/'report.htm');hb,mb,_=native(run/'report.htm')
    ignore=OPERATIONAL|{'InpRebreakMode','InpRebreakWaitBars'}
    assert {k:v for k,v in ma['inputs'].items() if k not in ignore}=={k:v for k,v in mb['inputs'].items() if k not in ignore}
    for k in ['broker','currency','symbol','period','initial_deposit','bars','ticks']:assert ha[k]==hb[k],k
    ea=check_environment(base,[ha['symbol']]);eb=check_environment(run,[hb['symbol']])
    assert ea['passed'] and eb['passed'] and ea['signature']==eb['signature']
    assert read(base/'history.csv',';')==read(run/'history.csv',';')
    runtime=[json.loads((p/n).read_text(encoding='utf-8-sig')) for p in [base,run] for n in ['runtime_before.json','runtime_after.json']]
    assert all(r==runtime[0] for r in runtime)
    cols=['time','signal','signal_reason','spread_atr','spread_allowed','atr']
    values=lambda p:[{k:r[k] for k in cols} for r in read(p/'funnel.csv',';')]
    assert values(base)==values(run),'Underlying signals changed'
    return dict(passed=True,signal_history_environment_inputs_runtime_match=True)


def check(run,spec,package):
    h,meta,nd=native(run/'report.htm')
    assert meta['from_date']==spec['date_from'] and meta['to_date']==spec['date_to']
    if spec['kind']=='harness':
        rows=read(run/'telemetry.csv',';');blocks=execution_blocks(meta,run/'journals');q=audit(meta,run/'journals')
        assert len(blocks)==1 and q['test_finished_in_block']
        assert len(rows)==15 and len({r['test'] for r in rows})==15 and all(r['passed']=='1' for r in rows)
        assert 'RB_QA_FINISH tests=15 errors=0' in '\n'.join(blocks[0]) and not nd
        save(run/'audit.json',dict(passed=True,tests=15,quality=q));return
    check_r5(run,dict(spec,expert='rebreak_adapter'),package)
    result=json.loads((run/'audit.json').read_text())
    expected=json.loads((package/'frozen'/spec['inputs']).read_text())
    assert {k:v for k,v in meta['inputs'].items() if k not in OPERATIONAL}=={k:v for k,v in expected.items() if k not in OPERATIONAL}
    deals=read(run/'cost.csv',';');risk=read(run/'risk.csv',';')
    result.update(audit_risk(risk,deals,float(expected['InpRiskPercent'])))
    entry_plan_coverage(deals,risk);audit_adjustments(read(run/'adjustment.csv',';'),risk,True)
    if spec['arm']!='reference':
        block='\n'.join(execution_blocks(meta,run/'journals')[0]);assert 'RB_FATAL' not in block
        finished=re.findall(r'RB_FINISH errors=(\d+) candidates=(\d+) starts=(\d+) outcomes=(\d+)',block)
        assert len(finished)==1 and int(finished[0][0])==0 and finished[0][2]==finished[0][3]
        names=['rb_candidates','rb_events','rb_entries','rb_outcomes','rb_bars','rb_context']
        data=[read(run/(n+'.csv'),';') for n in names]
        result['cohort']=check_cohort(*data)
        assert result['cohort']['candidates']==int(finished[0][1])
        signals=[r for r in read(run/'funnel.csv',';') if r['signal']=='true']
        assert len(signals)==len(data[0])
        ex=read(run/'rb_execution.csv',';');fills=[r for r in ex if r['status']=='FILLED']
        actual=[r for r in deals if r['entry_kind']=='0'];by_deal={r['deal']:r for r in actual}
        assert len(fills)==len(actual)
        entries=keyed(data[2],['id','arm'])
        for f in fills:
            assert f['arm']==spec['arm'] and f['result_deal'] in by_deal
            d=by_deal[f['result_deal']];s=entries[f['id'],f['arm']]
            assert d['time_msc']==f['time_msc']==s['time_msc']
            assert close(d['price'],s['ask']) and close(d['sl'],s['sl']) and close(d['tp'],s['tp'])
        intended=[r for r in data[2] if r['arm']==spec['arm']]
        assert len(ex)==len(intended) and len({r['id'] for r in ex})==len(ex),'Missing/duplicate execution decision'
    if spec.get('phase')=='qa' and spec['arm']=='A':
        base=run.parent/f"qa_{spec['symbol']}_reference";proof=market_pair(base,run)
        diff=deal_difference(read(base/'cost.csv',';'),deals)
        assert diff['execution_pass'] and diff['cash_pass']
        assert read(base/'risk.csv',';')==risk
        save(run/'baseline_parity.json',dict(proof,**diff))
    if spec['arm']=='B':
        base=run.parent/(spec['run_id'][:-1]+'A');proof=market_pair(base,run)
        for name in ['rb_candidates','rb_events','rb_entries','rb_outcomes','rb_context','rb_bars']:
            keys={'rb_candidates':['id'],'rb_events':['id'],'rb_entries':['id','arm'],'rb_outcomes':['id','arm'],'rb_context':['id','arm','tf'],'rb_bars':['bar_time']}[name]
            assert keyed(read(base/(name+'.csv'),';'),keys)==keyed(read(run/(name+'.csv'),';'),keys),('Shadow/cohort parity',name)
        save(run/'ab_cohort_parity.json',proof)
    save(run/'audit.json',result)
    print(json.dumps(dict(run=spec['run_id'],passed=True,actual=result['actual'],cohort=result.get('cohort'))))


def eligible(r):
    return r['outcome']!='END_CENSORED' and r['ambiguous_exit_minute']=='0' and r['exit_minute_complete']=='1'


def shadow_metrics(rows):
    good=[r for r in rows if eligible(r)];rs=[float(r['result_r']) for r in good]
    profit=sum(x for x in rs if x>0);loss=-sum(x for x in rs if x<0)
    avg=lambda k:sum(float(r[k]) for r in good)/len(good) if good else None
    return dict(n_total=len(rows),n_evaluable=len(good),excluded=len(rows)-len(good),
                win_rate=sum(x>0 for x in rs)/len(rs) if rs else None,expectancy_r=sum(rs)/len(rs) if rs else None,
                pf=profit/loss if loss else None,mfe_r=avg('mfe_r'),mae_r=avg('mae_r'))


def aggregate(batch,package):
    manifest=json.loads((package/'manifest.json').read_text());summaries=[];allrows=[];execution=[];monthly=[];transition=[];contextstats=[]
    for spec in manifest['runs']:
        folder=batch/spec['run_id'];a=json.loads((folder/'audit.json').read_text());assert a['passed']
        if spec['kind']=='harness' or spec.get('arm')=='reference':continue
        summaries.append(dict(run_id=spec['run_id'],phase=spec['phase'],symbol=spec['symbol'],arm=spec['arm'],**a['actual']))
        if spec['phase']=='qa':continue # QA is overlapping known data, never counted twice.
        ex=read(folder/'rb_execution.csv',';');trades=read(folder/'trades.csv')
        bydeal={r['deal']:r['position_id'] for r in read(folder/'cost.csv',';') if r['entry_kind']=='0'}
        pos={r['position_id']:r for r in trades}
        for r in ex:
            row=dict(run_id=spec['run_id'],symbol=spec['symbol'],**r)
            row['net_usd']=pos[bydeal[r['result_deal']]]['net'] if r['status']=='FILLED' else ''
            execution.append(row)
        start=datetime.strptime(spec['date_from'],'%Y.%m.%d');end=datetime.strptime(spec['date_to'],'%Y.%m.%d')
        for month in range(1,13):
            date=start.replace(month=month)
            if date>=end:break
            tag=date.strftime('%Y-%m')
            ts=[r for r in trades if r['entry_time'].startswith(tag)]
            decisions=[r for r in ex if datetime.fromtimestamp(int(r['time_msc'])/1000,timezone.utc).strftime('%Y-%m')==tag]
            monthly.append(dict(symbol=spec['symbol'],arm=spec['arm'],month=tag,trigger_opportunities=len(decisions),actual_entries=len(ts),net_usd=sum(float(r['net']) for r in ts)))
        if spec['arm']!='A':continue # Identical shadow export appears in both tester runs.
        candidates=read(folder/'rb_candidates.csv',';');ev=keyed(read(folder/'rb_events.csv',';'),['id'])
        ent=keyed(read(folder/'rb_entries.csv',';'),['id','arm']);out=keyed(read(folder/'rb_outcomes.csv',';'),['id','arm'])
        contexts=keyed(read(folder/'rb_context.csv',';'),['id','arm','tf'])
        year=spec['date_from'][:4]
        for c in candidates:
            id=c['id'];bstate=ev[id,]['event']
            ar=out[id,'A'];br=out.get((id,'B'))
            for arm in ['A','B']:
                entry=ent.get((id,arm));result=out.get((id,arm))
                row=dict(symbol=spec['symbol'],year=year,id=id,parent_group=c['parent_group'],arm=arm,
                         b_state=bstate,formed=entry is not None,signal_bar=c['signal_bar'],available_at=c['available_at'])
                for key in ['time_msc','ask','bid','atr','sl','tp','risk','spread_allowed']:row[key]=entry[key] if entry else ''
                for key in ['exit_msc','exit_price','outcome','result_r','mfe_r','mae_r','ambiguous_exit_minute','exit_minute_complete']:row[key]=result[key] if result else ''
                row['evaluable']=eligible(result) if result else False
                row['wait_minutes']=(int(entry['time_msc'])-int(ent[id,'A']['time_msc']))/60000 if entry else ''
                row['entry_change_in_a_r']=(float(entry['ask'])-float(ent[id,'A']['ask']))/float(ent[id,'A']['risk']) if entry else ''
                for tf in ['M15','H1','H4']:
                    ct=contexts.get((id,arm,'PERIOD_'+tf))
                    for key in ['regime','position','raw_position','location','break_direction','break_minutes']:
                        row[tf.lower()+'_'+key]=ct[key] if ct else ''
                        row['origin_a_'+tf.lower()+'_'+key]=contexts[id,'A','PERIOD_'+tf][key]
                allrows.append(row)
            transition.append(dict(symbol=spec['symbol'],year=year,id=id,parent_group=c['parent_group'],b_state=bstate,
                a_evaluable=eligible(ar),a_r=ar['result_r'],b_evaluable=eligible(br) if br else False,b_r=br['result_r'] if br else '',
                a_win_without_b=br is None and eligible(ar) and float(ar['result_r'])>0,
                a_loss_without_b=br is None and eligible(ar) and float(ar['result_r'])<0,
                entry_change_in_a_r=(float(ent[id,'B']['ask'])-float(ent[id,'A']['ask']))/float(ent[id,'A']['risk']) if br else ''))
    write(batch/'execution_statistics.csv',summaries);write(batch/'execution_ledger.csv',execution)
    write(batch/'monthly_execution.csv',monthly);write(batch/'candidate_comparison.csv',allrows);write(batch/'transition_ledger.csv',transition)
    stats=[]
    for symbol in manifest['symbols']:
        for year in ['ALL','2023','2024','2025','2026']:
            subset=[r for r in allrows if r['symbol']==symbol and (year=='ALL' or r['year']==year)]
            for arm in ['A','B']:
                rows=[r for r in subset if r['arm']==arm and r['formed']]
                stats.append(dict(symbol=symbol,year=year,arm=arm,base_candidates=len(subset)//2,**shadow_metrics(rows)))
                for feature in ['h1_regime','m15_position','h4_regime','origin_a_h1_regime','origin_a_m15_position','origin_a_h4_regime']:
                    for category in sorted({r[feature] for r in rows}):
                        group=[r for r in rows if r[feature]==category]
                        contextstats.append(dict(symbol=symbol,year=year,arm=arm,feature=feature,category=category,**shadow_metrics(group)))
    write(batch/'shadow_statistics.csv',stats);write(batch/'context_statistics.csv',contextstats)
    # Paired weekly block bootstrap, both entries formed and both outcomes evaluable.
    intervals=[];rng=np.random.default_rng(20261013)
    for symbol in manifest['symbols']:
        for period,years in [('KNOWN_2023_2024',{'2023','2024'}),('KNOWN_2025_2026',{'2025','2026'})]:
            pairs=[r for r in transition if r['symbol']==symbol and r['year'] in years and r['a_evaluable'] and r['b_evaluable']]
            blocks=defaultdict(list)
            byid={r['id']:r for r in allrows if r['arm']=='A'}
            for p in pairs:
                t=datetime.strptime(byid[p['id']]['available_at'],'%Y.%m.%d %H:%M:%S');week=t.strftime('%G-%V')
                blocks[week].append(float(p['b_r'])-float(p['a_r']))
            values=list(blocks.values());samples=[]
            if len(values)>=2:
                for _ in range(2000):
                    draws=rng.integers(0,len(values),len(values));sample=[v for j in draws for v in values[j]];samples.append(float(np.mean(sample)))
            intervals.append(dict(symbol=symbol,period=period,paired_n=len(pairs),week_blocks=len(values),
                mean_b_minus_a_r=float(np.mean([v for vs in values for v in vs])) if values else None,
                ci025=float(np.quantile(samples,.025)) if samples else None,ci975=float(np.quantile(samples,.975)) if samples else None,
                limitation='Conditional on both forming; use transition_ledger for selection/missed opportunities; known data'))
    write(batch/'paired_uncertainty.csv',intervals)
    lines=['# 上ヒゲ即時A / 終値再突破B：固定比較','','全runの機械監査合格。QA区間は研究集計へ二重加算していない。既知期間・生成tick、最適化/本番採用なし。','',
           '|銘柄|年|arm|元候補|成立|評価可能|勝率|平均R|PF|','|---|---|---|---:|---:|---:|---:|---:|---:|']
    fmt=lambda v:'NA' if v is None else f'{v:.4f}'
    for s in stats:lines.append(f"|{s['symbol']}|{s['year']}|{s['arm']}|{s['base_candidates']}|{s['n_total']}|{s['n_evaluable']}|{fmt(s['win_rate'])}|{fmt(s['expectancy_r'])}|{fmt(s['pf'])}|")
    lines+=['','B未成立は0Rに置換していない。ambiguous_exit_minute、観測未完了、END_CENSOREDはshadow主評価から除外。',
            '実行可能リプレイはactual MT5の全約定損益をそのまま別集計。曖昧取引を消して口座経路を作り直した結果ではない。',
            'candidate_comparison.csv: 全元候補×A/B、未成立、価格悪化、M15/H1/H4診断。',
            'execution_ledger.csv / monthly_execution.csv: 制約による見送りと実際の回数・損益。',
            'context_statistics.csv: H1方向/M15位置/H4方向を個別に比較。AND条件の探索なし。',
            'paired_uncertainty.csv: 両案成立例の差と週block区間。成功例だけの優位性と解釈せず、未成立をtransition_ledger.csvと併読。',
            '期間内で資金/保有状態は連続、各年のrun開始時に初期化。銘柄別独立口座であり合成portfolioではない。',
            '詳細な採否と年別/大勝依存の解釈は完了通知後に確認する。利益で自動採用する処理はない。']
    (batch/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path);a=p.parse_args()
    m=json.loads((a.package/'manifest.json').read_text())
    if a.run:check(a.run,next(s for s in m['runs'] if s['run_id']==a.run_id),a.package)
    else:aggregate(a.batch,a.package)
