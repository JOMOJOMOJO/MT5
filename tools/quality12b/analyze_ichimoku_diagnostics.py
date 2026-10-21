"""Fixed Ichimoku observer; reconstruct every field from exported closed OHLC."""
import argparse
from collections import defaultdict
from datetime import timedelta
import json
from pathlib import Path
from analyze_relative_search import read_csv,write_csv
import analyze_multitf_diagnostics as base
from analyze_m5_context import parity

SECS={'PERIOD_M15':900,'PERIOD_H1':3600,'PERIOD_H4':14400}
FIELDS=('cloud_location','cloud_direction','tk_order','kijun_slope','chikou_vs_old_range')
def order(a,b):return 'UP' if a>b else 'DOWN' if a<b else 'FLAT'
def location(p,hi,lo):return 'ABOVE' if p>hi else 'BELOW' if p<lo else 'INSIDE'

def calculate(bars,when,anchor,price,risk):
    closed=[b for b in bars if base.stamp(b['close_time'])<=when]
    closed=closed[-80:]
    if len(closed)<80:return None
    assert risk>0 and base.stamp(closed[-1]['close_time'])<=anchor<=when
    def mid(end,n):
        w=closed[end-n+1:end+1];assert len(w)==n
        return (max(float(b['high']) for b in w)+min(float(b['low']) for b in w))/2
    # q=80 denotes the CURRENT bar position, not the last closed bar (79).
    # Cloud displayed at q comes from q-26=54; Chikou uses j-26=53.
    j=79;src=54;lag=53
    a=(mid(src,9)+mid(src,26))/2;b=mid(src,52);top=max(a,b);bottom=min(a,b)
    tenkan=mid(j,9);kijun=mid(j,26);old=mid(j-3,26)
    cl=float(closed[j]['close']);hi=float(closed[lag]['high']);lo=float(closed[lag]['low'])
    return dict(tenkan=tenkan,kijun=kijun,kijun_3bars_ago=old,span_a=a,span_b=b,last_close=cl,
        lag_high=hi,lag_low=lo,asof=closed[j]['close_time'],cloud_source_bar=closed[src]['bar_time'],
        cloud_source_close=closed[src]['close_time'],lag_bar=closed[lag]['bar_time'],
        cloud_location=location(price,top,bottom),cloud_direction=order(a,b),tk_order=order(tenkan,kijun),
        kijun_slope=order(kijun,old),chikou_vs_old_range=location(cl,hi,lo),
        cloud_thickness_r=(top-bottom)/risk,distance_cloud_top_r=(price-top)/risk,
        distance_cloud_bottom_r=(price-bottom)/risk,distance_kijun_r=(price-kijun)/risk)

def check_run(folder,reference=None):
    candidates,actual=base.check_run(folder)
    metrics=json.loads((folder/'metrics.json').read_text(encoding='utf-8-sig'))
    assert not any('IC_CAUSAL_FAILURE' in line for block in base.execution_blocks(metrics['report'],folder/'journals/Tester') for line in block)
    ctx={(r['stage'],r['id']):r for r in candidates+actual}
    bars=defaultdict(list)
    for r in read_csv(folder/'ichi_bars.csv',';'):bars[(r['id'],r['tf'])].append(r)
    ichi=read_csv(folder/'ichi.csv',';');seen=set();feature_map=defaultdict(dict)
    for r in ichi:
        key=(r['stage'],r['id'],r['tf']);assert key not in seen;seen.add(key)
        c=ctx[key[:2]];when=base.stamp(r['decision_time']);anchor=base.stamp(r['cloud_anchor'])
        assert r['decision_time']==c['decision_time'] and r['time']==c['time']
        assert abs(float(r['price'])-float(c['price']))<1e-8
        assert when<=base.stamp(r['time'])
        block=bars.get((r['id'],r['tf']),[])
        if r['valid']=='1':
            assert len(block)==80 and len({b['bar_time'] for b in block})==80
            assert anchor<=when<anchor+timedelta(seconds=SECS[r['tf']])
            for b in block:
                assert base.stamp(b['close_time'])==base.stamp(b['bar_time'])+timedelta(seconds=SECS[r['tf']])
                assert base.stamp(b['close_time'])<=when
                assert float(b['low'])<=float(b['close'])<=float(b['high'])
            assert all(a['bar_time']<b['bar_time'] for a,b in zip(block,block[1:]))
            values=calculate(block,when,anchor,float(r['price']),float(c['ask'])-float(c['planned_sl']))
            for k,v in values.items():
                if isinstance(v,str):assert r[k]==v,(key,k,r[k],v)
                else:assert abs(float(r[k])-v)<1e-8,(key,k,r[k],v)
            # A future-only extreme bar must not affect any reconstructed feature.
            future=dict(block[-1],bar_time=(when+timedelta(days=1)).strftime('%Y.%m.%d %H:%M:%S'),
                        close_time=(when+timedelta(days=2)).strftime('%Y.%m.%d %H:%M:%S'),high='99999',low='0',close='77777')
            assert calculate(block+[future],when,anchor,float(r['price']),float(c['ask'])-float(c['planned_sl']))==values
        else:
            assert all(r[f]=='UNKNOWN' for f in FIELDS)
        prefix=r['tf'][7:].lower()+'_ichi_'
        feature_map[key[:2]].update({prefix+k:v for k,v in r.items() if k not in ('id','stage','tf','time','decision_time','price')})
    assert seen=={(stage,ident,tf) for stage,ident in ctx for tf in SECS}
    enriched_c=[dict(r,**feature_map[('CANDIDATE',r['id'])]) for r in candidates]
    enriched_t=[dict(r,**feature_map[('ENTRY',r['id'])]) for r in actual]
    write_csv(folder/'candidates_with_ichimoku.csv',enriched_c);write_csv(folder/'trades_with_ichimoku.csv',enriched_t)
    if reference:
        parity(folder,reference)
        # The observer must preserve raw candidates and their complete shadow paths too.
        for name in ('candidates_with_context.csv','trades_with_context.csv','path.csv'):
            delimiter=';' if name=='path.csv' else ','
            assert read_csv(folder/name,delimiter)==read_csv(reference.parent/name,delimiter),name
    audit=dict(passed=True,rows=len(ichi),ohlc_reconstructed=sum(r['valid']=='1' for r in ichi),
        unknown=sum(r['valid']!='1' for r in ichi),prefix_invariance=True,cloud_shift_bars=26,
        reference_population_and_path_equal=reference is not None)
    (folder/'ichimoku_audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    return enriched_c,enriched_t

def statistics(rows,actual):
    groups=defaultdict(list)
    for r in rows:
        for period in ('ALL',r['year']):
            for tf in ('m15','h1','h4'):
                for field in FIELDS:
                    groups[(period,tf,field,r[tf+'_ichi_'+field])].append(r)
                # Limited, predeclared sensitivity check; no hour/3TF AND search.
                groups[(period,tf,'cloud_x_spread',r[tf+'_ichi_cloud_location']+'|'+base.spread_bin(r['spread_atr']))].append(r)
    return [dict(period=k[0],tf=k[1],feature=k[2],category=k[3],small_sample=len(v)<30,
                 **base.summary(v,actual)) for k,v in sorted(groups.items())]

def analyze(batch,package):
    base.analyze(batch,package)
    spec=json.loads((package/'manifest.json').read_text());raw=[];actual=[]
    root=Path(__file__).resolve().parents[2]
    for run in spec['runs']:
        c,t=check_run(batch/run['run_id'],root/run['reference_report'])
        if run['stage']=='Control':continue
        raw.extend(dict(r,run_id=run['run_id']) for r in c);actual.extend(dict(r,run_id=run['run_id']) for r in t)
    write_csv(batch/'candidates_with_ichimoku.csv',raw);write_csv(batch/'trades_with_ichimoku.csv',actual)
    ss=statistics(raw,False);aa=statistics(actual,True)
    write_csv(batch/'ichimoku_shadow_statistics.csv',ss);write_csv(batch/'ichimoku_actual_statistics.csv',aa)
    lines=['# 一目均衡表の観測検証','',
        '9/26/52固定。M5売買条件・SL/TP・リスクは変更していない。全runで前回との売買・raw候補・shadow pathの一致を監査。',
        f'本集計は全候補{len(raw)}件、実取引{len(actual)}件。既知期間、生成tick混在。条件採用なし。','',
        '## 雲の上・中・下：全候補shadow（コストはspreadのみ、両側到達分を除外）','',
        '|期間|TF|雲位置|n|平均R|PF|','|---|---|---|---:|---:|---:|']
    for r in ss:
        if r['feature']=='cloud_location':
            avg='NA' if r['mean_price_r'] is None else f"{r['mean_price_r']:+.3f}"
            pf='NA' if r['pf_price_r'] is None else f"{r['pf_price_r']:.3f}"
            lines.append(f"|{r['period']}|{r['tf']}|{r['category']}|{r['n']}|{avg}|{pf}|")
    lines+=['','## 注意','',
        'current-bar cloudは現在の足位置qに描くためq−26で計算。転換線/基準線は最新確定足q−1。形成中のOHLCは不使用。',
        '遅行関係は確定終値を26本前の高安と比較した診断値。未来の終値が入りうる遅行バッファを過去時点から参照していない。',
        '雲厚/基準線との距離は元の予定リスク幅Rで正規化。基準線傾きは確定足3本差。閾値探索なし。',
        '全候補と実取引を混ぜない。小標本・候補間依存・年別反転・spreadとの交絡を確認するまで採用しない。',
        '基礎結果はcandidates_with_context.csv等、一目追加結果はcandidates_with_ichimoku.csv等。計算監査元は各runのichi_bars.csv。',
        '公式定義：https://www.metatrader5.com/en/terminal/help/indicators/trend_indicators/ikh']
    (batch/'ichimoku_summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',type=Path);p.add_argument('--reference',type=Path)
    p.add_argument('--batch',type=Path);p.add_argument('--package',type=Path);a=p.parse_args()
    if a.run:check_run(a.run,a.reference)
    else:analyze(a.batch,a.package)
