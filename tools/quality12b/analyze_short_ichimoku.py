"""SELL study: Bid entry, Ask path; existing LONG results remain untouched."""
import argparse,json,re,hashlib
from collections import defaultdict,Counter
from datetime import timedelta
from pathlib import Path
from analyze_relative_search import read_csv,write_csv,months
from analyze_m5_context import parity,extended_stats
import analyze_multitf_diagnostics as base
import analyze_ichimoku_diagnostics as ichi

def short_shadow(c,path):
    assert float(c['price'])==float(c['bid'])
    mirrored=dict(c,price=-float(c['price']),planned_sl=-float(c['planned_sl']),planned_tp=-float(c['planned_tp']))
    mirror_path=[dict(p,open_bid=-float(p['open_ask']),high_bid=-float(p['low_ask']),
        low_bid=-float(p['high_ask']),close_bid=-float(p['close_ask'])) for p in path]
    return base.shadow(mirrored,mirror_path)

def check_ichi(folder,ctx):
    bars=defaultdict(list)
    for r in read_csv(folder/'ichi_bars.csv',';'):bars[(r['id'],r['tf'])].append(r)
    rows=read_csv(folder/'ichi.csv',';');seen=set();features=defaultdict(dict)
    for r in rows:
        key=(r['stage'],r['id'],r['tf']);assert key not in seen;seen.add(key)
        c=ctx[key[:2]];when=base.stamp(r['decision_time']);anchor=base.stamp(r['cloud_anchor'])
        assert r['decision_time']==c['decision_time'] and r['time']==c['time'] and when<=base.stamp(r['time'])
        assert abs(float(r['price'])-float(c['price']))<1e-8
        block=bars.get((r['id'],r['tf']),[])
        if r['valid']=='1':
            assert len(block)==80 and len({b['bar_time'] for b in block})==80
            assert anchor<=when<anchor+timedelta(seconds=ichi.SECS[r['tf']])
            for b in block:
                assert base.stamp(b['close_time'])==base.stamp(b['bar_time'])+timedelta(seconds=ichi.SECS[r['tf']])
                assert base.stamp(b['close_time'])<=when and float(b['low'])<=float(b['close'])<=float(b['high'])
            assert all(a['bar_time']<b['bar_time'] for a,b in zip(block,block[1:]))
            risk=float(c['planned_sl'])-float(c['bid'])
            values=ichi.calculate(block,when,anchor,float(r['price']),risk)
            for k,v in values.items():
                if isinstance(v,str):assert r[k]==v,(key,k)
                else:assert abs(float(r[k])-v)<1e-8,(key,k,r[k],v)
            future=dict(block[-1],close_time=(when+timedelta(days=2)).strftime('%Y.%m.%d %H:%M:%S'),high='999999',low='0',close='7777')
            assert ichi.calculate(block+[future],when,anchor,float(r['price']),risk)==values
        else:assert all(r[f]=='UNKNOWN' for f in ichi.FIELDS)
        features[key[:2]].update({r['tf'][7:].lower()+'_ichi_'+k:v for k,v in r.items() if k not in ('id','stage','tf','time','decision_time','price')})
    assert seen=={(stage,ident,tf) for stage,ident in ctx for tf in ichi.SECS}
    return features,len(rows)

def check_run(folder,reference=None):
    m=json.loads((folder/'metrics.json').read_text(encoding='utf-8-sig'));assert m['audit']['passed']
    blocks=base.execution_blocks(m['report'],folder/'journals/Tester');assert len(blocks)==1
    text='\n'.join(blocks[0]);assert 'thread finished' in text
    assert not re.search(r'array out of range|zero divide|critical error|DC_CAUSAL_OR_PARITY_FAILURE|IC_CAUSAL_FAILURE',text,re.I)
    risks=re.findall(r'RISK volume=[\d.]+ expected_loss=([\d.]+) budget=([\d.]+)',text)
    assert all(float(a)<=float(b)+.00011 for a,b in risks)
    trades=read_csv(folder/'trades.csv')
    assert all(t['side']=='sell' and float(t['initial_tp'])<float(t['entry_price'])<float(t['initial_sl']) for t in trades)
    quality=base.audit(m['report'],folder/'journals/Tester')
    if m['report']['inputs']['InpShortObserver']=='false':
        assert not read_csv(folder/'context.csv',';')
        (folder/'short_audit.json').write_text(json.dumps(dict(passed=True,observer=False,trades=len(trades),risk_plans=len(risks),quality=quality),indent=2))
        return [],[]
    groups=defaultdict(list);paths=defaultdict(list)
    for r in read_csv(folder/'context.csv',';'):groups[(r['stage'],r['id'])].append(r)
    for r in read_csv(folder/'path.csv',';'):paths[r['id']].append(r)
    ctx={k:base.flatten(v) for k,v in groups.items()}
    candidates={k[1]:v for k,v in ctx.items() if k[0]=='CANDIDATE'}
    entries={k[1]:v for k,v in ctx.items() if k[0]=='ENTRY'}
    assert set(paths)==set(candidates) and set(entries)<=set(candidates)
    funnel=read_csv(folder/'funnel.csv',';')
    assert {r['time'] for r in funnel if r['signal'] in ('true','1')}==set(candidates)
    assert len(trades)==len(entries)
    features,observations=check_ichi(folder,ctx)
    trade_by_time={t['entry_time']:t for t in trades};assert len(trade_by_time)==len(trades)
    actual=[]
    for ident,e in entries.items():
        t=trade_by_time[base.stamp(e['time']).isoformat(sep=' ')]
        assert abs(float(t['entry_price'])-float(e['price']))<1e-8
        assert candidates[ident]['execution_gate']=='1'
        actual.append(dict(e,**t,**features[('ENTRY',ident)],tick_quality=quality['category']))
    out=[]
    for ident,c in candidates.items():
        assert float(c['planned_tp'])<float(c['price'])<float(c['planned_sl'])
        reasons=[]
        if c['spread_allowed']=='0':reasons.append('SPREAD')
        for key in ('daily_cap','equity_cap','uncertain_send'):
            if c[key]=='1':reasons.append(key.upper())
        if int(c['positions'])>0:reasons.append('POSITION_OCCUPIED')
        cap=int(m['report']['inputs']['InpMaxTradesPerDay'])
        if cap>0 and int(c['daily_entries'])>=cap:reasons.append('DAILY_TRADE_COUNT')
        if ident not in entries and not reasons:reasons.append('OTHER_GATE_OR_ORDER_REJECTION')
        out.append(dict(c,**features[('CANDIDATE',ident)],side='sell',executed=int(ident in entries),gate_flags='|'.join(reasons),
            tick_quality=quality['category'],**short_shadow(c,paths[ident])))
    write_csv(folder/'candidates_with_ichimoku.csv',out);write_csv(folder/'trades_with_ichimoku.csv',actual)
    if reference:
        parity(folder,reference)
        assert read_csv(folder/'funnel.csv',';')==read_csv(reference.parent/'funnel.csv',';')
        assert len(trades)>0,'Control has zero trades; full parity is uninformative'
    (folder/'short_audit.json').write_text(json.dumps(dict(passed=True,observer=True,observations=observations,
        candidates=len(out),trades=len(actual),risk_plans=len(risks),quality=quality,bid_entry_ask_path=True,
        causal_ichimoku_reconstruction=True,observer_parity=reference is not None),indent=2))
    return out,actual

def analyze(batch,package):
    spec=json.loads((package/'manifest.json').read_text());raw=[];actual=[];monthly=[]
    for run in spec['runs']:
        ref=batch/run['reference_run_id']/'report.htm' if 'reference_run_id' in run else None
        c,t=check_run(batch/run['run_id'],ref)
        if run['stage']=='Control':continue
        raw.extend(dict(r,run_id=run['run_id']) for r in c);actual.extend(dict(r,run_id=run['run_id']) for r in t)
        for month in months(run['date_from'],run['date_to']):
            monthly.append(dict(run_id=run['run_id'],month=month,candidates=sum(r['month']==month for r in c),executions=sum(r['month']==month for r in t)))
    write_csv(batch/'candidates_with_ichimoku.csv',raw);write_csv(batch/'trades_with_ichimoku.csv',actual)
    write_csv(batch/'monthly_counts.csv',monthly)
    write_csv(batch/'ichimoku_shadow_statistics.csv',ichi.statistics(raw,False))
    write_csv(batch/'ichimoku_actual_statistics.csv',ichi.statistics(actual,True))
    write_csv(batch/'environment_shadow_statistics.csv',base.aggregate(raw,False))
    write_csv(batch/'environment_actual_statistics.csv',base.aggregate(actual,True))
    counts=Counter((r['year'],r['gate_flags'] or 'EXECUTED') for r in raw)
    write_csv(batch/'execution_gate_counts.csv',[dict(year=k[0],flags=k[1],n=n) for k,n in sorted(counts.items())])
    years=[dict(year=y,**extended_stats([r for r in actual if r['year']==y])) for y in ('2023','2024','2025','2026')]
    write_csv(batch/'annual_statistics.csv',years)
    root=Path(__file__).resolve().parents[2];ref=root/spec['long_reference']['path']
    assert hashlib.sha256(ref.read_bytes()).hexdigest()==spec['long_reference']['sha256']
    long_trades=read_csv(ref);comparison=[]
    for side,trades,cloud in [('LONG',long_trades,'ABOVE'),('SHORT',actual,'BELOW')]:
        for period in ('ALL','2023','2024','2025','2026'):
            denominator=45 if period=='ALL' else 9 if period=='2026' else 12
            for group in ('ALL','H4_DIRECTIONAL_CLOUD'):
                selected=[r for r in trades if (period=='ALL' or r['year']==period) and
                          (group=='ALL' or r['h4_ichi_cloud_location']==cloud)]
                comparison.append(dict(side=side,period=period,group=group,observed_monthly=len(selected)/denominator,**extended_stats(selected)))
    write_csv(batch/'long_short_comparison.csv',comparison)
    lines=['# M5ショート反転版：固定検証','',
        'M5ロング継続条件の上下反転。USDJPY、SL2.2ATR、RR1.5、risk0.65%、spread上限0.20ATR、保有18本。',
        '一目9/26/52は記録のみ。H4雲下によるEntry除外もまだ実装しない。別テストのショート単独結果。ロングとの同時運用は未検証。',
        f'raw候補{len(raw)}件、実取引{len(actual)}件、月平均実行{len(actual)/len(monthly):.2f}件。',
        f'実取引: {json.dumps(extended_stats(actual))}',f'Shadow: {json.dumps(base.summary(raw,False))}','',
        '## H4の雲位置：既存実取引の分類','',
        '|年|雲位置|n|純損益 USD|PF|平均R|','|---|---|---:|---:|---:|---:|']
    for r in ichi.statistics(actual,True):
        if r['tf']=='h4' and r['feature']=='cloud_location':
            lines.append(f"|{r['period']}|{r['category']}|{r['n']}|{r['net']:.2f}|{r['pf']}|{r['mean_price_r']}|")
    lines+=['','## 解釈','',
        'Bid Entry / Ask決済のshadow。Bidを決済価格に流用しない。1分内SL/TP両到達は除外して残す。',
        'MFE/MAEは18本の固定窓で、先にSL/TP到達した後も含む。shadowはcommission/swapや発注制限を含まない。',
        'LONGの結果を反転して予測するものではない。実測損益、spread制約、年別再現性、頻度で評価する。',
        'long_short_comparison.csvは別テスト同士の比較。H4_DIRECTIONAL_CLOUDは既存取引の事後分類で、雲フィルターの再テストではない。',
        '既知期間、混在tickの品質ラベル付き。最高区分や閾値の選択・本番採用は行わない。']
    (batch/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',type=Path);p.add_argument('--reference',type=Path)
    p.add_argument('--batch',type=Path);p.add_argument('--package',type=Path);a=p.parse_args()
    if a.run:check_run(a.run,a.reference)
    else:analyze(a.batch,a.package)
