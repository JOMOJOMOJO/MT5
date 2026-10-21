"""Descriptive regime x position study. Frozen trades; causal closed-bar features."""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from analyze_m15_progress import pivots
from analyze_m15_phase_research import stat

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/three_wave/m15_phase_research'
OUT=ROOT/'reports/qa/three_wave/m15_regime_position_research'
RUNS=['known_close_2025h1','holdout_close_2024q3']
REGIMES=['UP','DOWN','RANGE','UNKNOWN'];POSITIONS=['LOW','MID','HIGH','UNKNOWN']
CATS=[r+'_'+p for r in REGIMES[:3] for p in POSITIONS[:3]]+['UNKNOWN_UNKNOWN']

def regime(h,l):
    if len(h)<2 or len(l)<2:return 'UNKNOWN'
    dh=h[-1][0]-h[-2][0];dl=l[-1][0]-l[-2][0]
    return 'UP' if dh>0 and dl>0 else ('DOWN' if dh<0 and dl<0 else 'RANGE')

def position(raw):
    if pd.isna(raw):return 'UNKNOWN'
    return 'LOW' if raw<=1/3 else ('MID' if raw<=2/3 else 'HIGH')

def replay(b):
    a=b[['high','low','close']].to_numpy();ts=b.bar.to_numpy();times=b['asof'].to_numpy()
    hs=[];ls=[];used=set();last={};rows=[];events=[];previous='UNKNOWN'
    for i,(_,__,close) in enumerate(a):
        now=int(times[i])
        for side,price,k in pivots(a,i):
            v=hs if side==0 else ls;v.append((float(price),int(ts[k]),now));del v[:-2]
        state=regime(hs,ls)
        for direction,points in [('bullish',hs),('bearish',ls)]:
            if not points:continue
            price,bar,confirmed=points[-1];key=(direction,bar)
            broken=close>price if direction=='bullish' else close<price
            if broken and key not in used:
                reversal=(direction=='bullish' and previous=='DOWN') or (direction=='bearish' and previous=='UP')
                event=dict(asof=now,direction=direction,level=price,level_bar=bar,level_confirmed=confirmed,
                           previous_regime=previous,regime_at_break=state,is_reversal_break=reversal)
                events.append(event);last[direction]=event;used.add(key)
        row=dict(asof=now,regime=state)
        for name,p in [('high_old',hs[0] if len(hs)==2 else None),('high_new',hs[-1] if hs else None),
                       ('low_old',ls[0] if len(ls)==2 else None),('low_new',ls[-1] if ls else None)]:
            row[name]=p[0] if p else np.nan;row[name+'_bar']=p[1] if p else 0;row[name+'_confirmed']=p[2] if p else 0
        row['structure_high']=max(p[0] for p in hs) if len(hs)==2 else np.nan
        row['structure_low']=min(p[0] for p in ls) if len(ls)==2 else np.nan
        for direction in ['bullish','bearish']:
            e=last.get(direction)
            for field in ['asof','level','level_bar','level_confirmed']:
                row[direction+'_break_'+field]=e[field] if e else np.nan
        rows.append(row);previous=state
    return pd.DataFrame(rows),pd.DataFrame(events)

def annotate(c,r):
    x=c.copy();x['entry_sec']=x.entry_msc/1000
    x=pd.merge_asof(x.sort_values('entry_sec'),r.assign(asof=r['asof'].astype(float)),left_on='entry_sec',right_on='asof')
    width=x.structure_high-x.structure_low
    x['raw_position']=np.where((width>0)&x.regime.ne('UNKNOWN'),(x.entry-x.structure_low)/width,np.nan)
    x['position_0_1']=x.raw_position.clip(0,1);x['position']=x.position_0_1.map(position)
    x['range_location']=np.select([x.raw_position.isna(),x.raw_position<0,x.raw_position>1],['UNKNOWN','BELOW','ABOVE'],default='INSIDE')
    x['category']=x.regime+'_'+x.position
    for direction in ['bullish','bearish']:
        prefix=direction+'_break_';t=x[prefix+'asof']
        x['has_'+direction+'_break']=t.notna()
        x[prefix+'age_minutes']=(x.entry_sec-t)/60
        x[prefix+'level_minus_entry']=x[prefix+'level']-x.entry
        x[prefix+'level_minus_entry_r']=x[prefix+'level_minus_entry']/x.risk
    latest_bull=x.bullish_break_asof.fillna(-np.inf)>x.bearish_break_asof.fillna(-np.inf)
    x['last_break_direction']=np.where(latest_bull,'bullish','bearish')
    for suffix in ['asof','level','level_bar','level_confirmed']:
        x['last_break_'+suffix]=np.where(latest_bull,x['bullish_break_'+suffix],x['bearish_break_'+suffix])
    x.loc[x.last_break_asof.isna(),'last_break_direction']='NONE'
    x['last_break_age_minutes']=(x.entry_sec-x.last_break_asof)/60
    x['last_break_level_minus_entry']=x.last_break_level-x.entry
    x['last_break_level_minus_entry_r']=x.last_break_level_minus_entry/x.risk
    x['last_break_absolute_distance_r']=x.last_break_level_minus_entry_r.abs()
    return x

def future(x,r,e):
    rows=[];end=r['asof'].iloc[-1]
    for _,c in x.iterrows():
        after=e[e['asof']>c.entry_sec]
        streams={'bullish_break':after[after.direction=='bullish']['asof'],
                 'bearish_break':after[after.direction=='bearish']['asof'],
                 'reversal_break':after[after.is_reversal_break]['asof']}
        opposite={'UP':'DOWN','DOWN':'UP'}.get(c.regime)
        streams['opposite_pivot_regime']=r[(r['asof']>c.entry_sec)&r.regime.eq(opposite)]['asof']
        row=dict(id=c.id,future_observed_minutes=(end-c.entry_sec)/60)
        for name,times in streams.items():
            valid=name!='opposite_pivot_regime' or opposite is not None
            first=times.iloc[0] if valid and len(times) else np.nan
            minutes=(first-c.entry_sec)/60
            row['future_'+name+'_first_asof']=first;row['future_'+name+'_minutes']=minutes
            for window in [30,60,120]:
                row[f'future_{name}_within_{window}m']=(True if minutes<=window else
                    (False if valid and row['future_observed_minutes']>=window else pd.NA))
        rows.append(row)
    return pd.DataFrame(rows)

def md_table(d):
    def f(x):
        if pd.isna(x):return '—'
        return f'{x:.3f}' if isinstance(x,(float,np.floating)) else str(x)
    return '\n'.join(['| '+' | '.join(map(str,d.columns))+' |','| '+' | '.join(['---']*len(d.columns))+' |']+
        ['| '+' | '.join(f(x) for x in v)+' |' for v in d.itertuples(index=False,name=None)])

def main():
    OUT.mkdir(exist_ok=True,parents=True)
    assert [position(x) for x in [-.1,0,1/3,1/3+1e-10,2/3,2/3+1e-10,1,1.1,np.nan]]==['LOW','LOW','LOW','MID','MID','HIGH','HIGH','HIGH','UNKNOWN']
    allc=[];alld=[];alle=[];checks=[];hashes={}
    for run in RUNS:
        p=BASE/run;c=pd.read_csv(p/'MP_candidates.csv');o=pd.read_csv(p/'MP_outcomes.csv');b=pd.read_csv(p/'MP_phases.csv')
        for name in ['MP_candidates.csv','MP_outcomes.csv','MP_phases.csv','tick_quality.json']:
            hashes[str((p/name).relative_to(ROOT))]=hashlib.sha256((p/name).read_bytes()).hexdigest()
        r,e=replay(b);x=annotate(c,r)
        cuts=[len(b)//2,len(b)-50]
        for cut in cuts:
            pr,pe=replay(b.iloc[:cut]);pd.testing.assert_frame_equal(pr,r.iloc[:cut])
            pd.testing.assert_frame_equal(pe,e[e['asof']<=b['asof'].iloc[cut-1]].reset_index(drop=True))
        altered=b.copy();altered.loc[cuts[0]:,['high','low','close']]*=1.1
        ar,_=replay(altered);pd.testing.assert_frame_equal(ar.iloc[:cuts[0]],r.iloc[:cuts[0]])
        rr,ee=replay(b);pd.testing.assert_frame_equal(rr,r);pd.testing.assert_frame_equal(ee,e)
        assert x['asof'].le(x.entry_sec).all()
        for name in ['high_old','high_new','low_old','low_new']:
            assert x[name+'_confirmed'].le(x.entry_sec).all()
        for direction in ['bullish','bearish']:
            t=x[direction+'_break_asof'];assert t.dropna().le(x.loc[t.notna(),'entry_sec']).all()
        assert (e.level_confirmed<=e['asof']).all()
        for direction in ['bullish','bearish']:
            g=e[e.direction==direction];close=b.set_index('asof').loc[g['asof'],'close'].to_numpy()
            assert ((close>g.level.to_numpy()) if direction=='bullish' else (close<g.level.to_numpy())).all()
        x=x.merge(future(x,r,e),on='id',validate='one_to_one')
        warnings=json.loads((p/'tick_quality.json').read_text())['warning_days']
        x['entry_on_tick_warning_day']=pd.to_datetime(x.entry_msc,unit='ms').dt.strftime('%Y.%m.%d').isin(warnings)
        x['month']=pd.to_datetime(x.entry_msc,unit='ms').dt.strftime('%Y-%m');x['run']=run
        d=o.merge(x[['id','regime','position','category','range_location','month']],on='id',validate='many_to_one');d['run']=run
        d['complete']=d.outcome.isin(['SL','TP']);d['path_complete']=d.path_complete.astype(str).str.lower().isin(['true','1'])
        pd.testing.assert_frame_equal(o.sort_values(['id','rr']).reset_index(drop=True),d[o.columns].sort_values(['id','rr']).reset_index(drop=True))
        r.to_csv(OUT/(run+'_m15_states.csv'),index=False);e['run']=run
        allc.append(x);alld.append(d);alle.append(e)
        checks.append(dict(run=run,candidates=len(x),prefix_invariance='PASS',future_perturbation='PASS',repeat_replay='PASS',
                           pivot_and_break_causality='PASS',all_original_outcome_columns_unchanged='PASS'))
    cs=pd.concat(allc);ds=pd.concat(alld);es=pd.concat(alle)
    assert len(cs)==119 and len(ds)==476
    cs.to_csv(OUT/'candidates_with_environment.csv',index=False);ds.to_csv(OUT/'fixed_rr_outcomes.csv',index=False)
    es.to_csv(OUT/'structure_break_events.csv',index=False)
    stats=[];monthly=[];cross=[]
    for run in RUNS+['ALL_PERIODS']:
        source=ds if run=='ALL_PERIODS' else ds[ds.run==run]
        for scope in ['ALL_CANDIDATES','INSIDE_ONLY_DIAGNOSTIC']:
            frame=source if scope=='ALL_CANDIDATES' else source[source.range_location=='INSIDE']
            for rr in [1.,1.2,1.5,2.]:
                for cat in CATS+['ALL']:
                    g=frame[frame.rr==rr];g=g if cat=='ALL' else g[g.category==cat]
                    stats.append(dict(run=run,scope=scope,rr=rr,category=cat,**stat(g)))
        candidates=cs if run=='ALL_PERIODS' else cs[cs.run==run]
        for cat in CATS:
            g=candidates[candidates.category==cat]
            cross.append(dict(run=run,regime=cat.rsplit('_',1)[0],position=cat.rsplit('_',1)[1],count=len(g),
                              outside_count=int(g.range_location.isin(['BELOW','ABOVE']).sum())))
        if run!='ALL_PERIODS':
            cfg=(BASE/run/'test.ini').read_text();dates={l.split('=')[0]:l.split('=')[1] for l in cfg.splitlines() if l.startswith(('FromDate=','ToDate='))}
            months=pd.period_range(pd.Timestamp(dates['FromDate']),pd.Timestamp(dates['ToDate'])-pd.Timedelta(days=1),freq='M').astype(str)
            for month in months:
                for cat in CATS:
                    monthly.append(dict(run=run,month=month,category=cat,count=int(((candidates.month==month)&(candidates.category==cat)).sum())))
    st=pd.DataFrame(stats);st.to_csv(OUT/'category_statistics.csv',index=False)
    pd.DataFrame(monthly).to_csv(OUT/'monthly_counts.csv',index=False)
    ct=pd.DataFrame(cross);ct.to_csv(OUT/'regime_position_matrix.csv',index=False)
    # Continuous associations only. No quantile bins or fitted cutoffs.
    features=['raw_position','last_break_age_minutes','last_break_level_minus_entry_r','last_break_absolute_distance_r',
              'bullish_break_age_minutes','bearish_break_age_minutes']
    corr=[]
    for run in RUNS:
        z=ds[ds.run==run].merge(cs[cs.run==run][['id']+features],on='id',validate='many_to_one')
        for rr in [1.,1.2,1.5,2.]:
            for f in features:
                q=z[z.rr==rr][[f,'result_r']].dropna()
                corr.append(dict(run=run,rr=rr,feature=f,n=len(q),spearman_rho=q[f].rank().corr(q.result_r.rank())))
    pd.DataFrame(corr).to_csv(OUT/'continuous_associations.csv',index=False)
    transitions=[]
    for run in RUNS+['ALL_PERIODS']:
        q=cs if run=='ALL_PERIODS' else cs[cs.run==run]
        for cat in CATS+['ALL']:
            g=q if cat=='ALL' else q[q.category==cat]
            row=dict(run=run,category=cat,count=len(g),last_bullish_count=int(g.last_break_direction.eq('bullish').sum()),
                     last_bearish_count=int(g.last_break_direction.eq('bearish').sum()),
                     median_last_break_age_minutes=g.last_break_age_minutes.median(),
                     median_last_break_absolute_distance_r=g.last_break_absolute_distance_r.median())
            for kind in ['bullish_break','bearish_break','reversal_break','opposite_pivot_regime']:
                for window in [30,60,120]:
                    col=f'future_{kind}_within_{window}m';v=g[col].dropna()
                    row[col+'_count']=int(v.sum());row[col+'_observed']=len(v);row[col+'_rate']=v.mean() if len(v) else np.nan
            transitions.append(row)
    pd.DataFrame(transitions).to_csv(OUT/'transition_diagnostics.csv',index=False)
    (OUT/'audit.json').write_text(json.dumps(checks,indent=2));(OUT/'source_hashes.json').write_text(json.dumps(hashes,indent=2))
    report(cs,st,ct)
    print(st[(st.scope=='ALL_CANDIDATES')&(st.rr==1.2)][['run','category','count','expectancy_r']].to_string(index=False))

def report(c,s,ct):
    parts=['''# M15方向 × 価格位置：記述的研究

既存119候補・476結果の分類のみを追加。Entry・SL・TP・売買EA・Sharedは変更していない。新規MT5実行ではなく保存済み確定M15足の再分析。条件採用・閾値探索なし。

## 分類

最新2つの確定高値・確定安値が共に上昇ならUP、共に下降ならDOWN、混在・同値はRANGE、不足はUNKNOWN。構造範囲はその2高値のmaxと2安値のmin。Entry Askの位置を正規化し、1/3以下LOW、2/3以下MID、それ以上HIGH。breakは別の特徴でありregimeを上書きしない。

構造外は元のraw_positionとBELOW/ABOVEを残し、0〜1の値のみclip。構造外を除いた同じ集計もINSIDE_ONLY_DIAGNOSTICとして保存。これを採用フィルターにしていない。[事前定義](plan.md)。

## 必須2軸表：regime × position
''']
    for run in RUNS+['ALL_PERIODS']:
        v=ct[ct.run==run].pivot(index='regime',columns='position',values='count').reindex(index=REGIMES,columns=POSITIONS).fillna(0).astype(int)
        parts+=['### '+run,md_table(v.reset_index())]
        for rr in [1.,1.2,1.5,2.]:
            q=s[(s.run==run)&(s.scope=='ALL_CANDIDATES')&(s.rr==rr)]
            parts+=['#### RR'+str(rr)+'：カテゴリ別成績',md_table(q[['category','count','win_rate','expectancy_r','pf']])]
        q=s[(s.run==run)&(s.scope=='ALL_CANDIDATES')&(s.rr==1.2)]
        parts+=['#### TPなしSL/24h観測のMFE/MAEと到達率（割合0〜1）',
                md_table(q[['category','path_n','mean_mfe_24h','mean_mae_24h','reach_1.0r','reach_1.2r','reach_1.5r','reach_2.0r']])]
    parts+=['## 月別件数',md_table(pd.read_csv(OUT/'monthly_counts.csv').pivot(index='month',columns='category',values='count').reset_index()),
            '## 構造外の件数',md_table(c.groupby(['run','range_location']).size().rename('count').reset_index()),
            '''## 転換特徴の読み方

- bullish/bearish breakは最新確定pivotの初回終値突破。同じpivotを何度もbreakとして数えない。両方向の最終break・最後の方向・経過分・level・符号付き距離Rと絶対距離Rを保存。
- has_bullish_break / has_bearish_breakは記録開始以降に存在するというフラグ。「最近」を恣意的な時間で区切っていないので経過分と一緒に読む。
- reversal_breakは直前既知regimeと逆方向のbreak。pivotによるUP↔DOWN確定とは異なる。
- future_*はEntry後の診断専用。30/60/120分の各方向break・転換break、Entry時点のUP/DOWNから反対のpivot regimeへ変わったかを区別。RANGEからのopposite_pivot_regimeは未定義。観測窓不足は欠損。
- 転換特徴を細かいbinに分けず、連続値のSpearman順位相関を保存。多数の相関のうち良いものを採用しない。因果効果や予測精度の証明ではない。

## QA・限界

- 途中切断、未来OHLC改変、2回再生で過去の状態・特徴・breakイベントが不変。pivotとbreakの情報利用可能時刻を監査。
- 119候補・476結果の元の全損益列が一致。カテゴリを付けただけなので母集団・実行可能数は変わらない。
- 両期間とも既知でありOOSではない。2024年Q3は生成ティックへの置換が多く、Entry警告日フラグを継承。
- 価格Rはspread込み、commission/swap/滑り/証拠金は含まない。PFも金額ではなくRベース。損失0件のPFは空欄。
- 小標本、同一親候補の依存、月別相場差がある。合算成績だけで結論しない。RANGEは混在pivot構造であり横ばいを保証しない。
- 相場方向は確定pivotを使うため価格の転換より遅れる。独立break特徴と併読し、遅れを後からカテゴリ書換えで解消しない。

## ファイル

- [全候補・転換特徴・将来ラベル](candidates_with_environment.csv)
- [固定RR結果](fixed_rr_outcomes.csv) / [カテゴリ全統計](category_statistics.csv)
- [2軸表CSV](regime_position_matrix.csv) / [月別件数](monthly_counts.csv)
- [breakイベント](structure_break_events.csv) / [連続値との関係](continuous_associations.csv)
- [カテゴリ別の転換特徴・将来ラベル集計](transition_diagnostics.csv)
- [監査](audit.json) / [元データhash](source_hashes.json)

再実行：`python tools/swing_structure/analyze_m15_regime_position.py`
''']
    (OUT/'tables.md').write_text('\n\n'.join(parts),encoding='utf-8')
    fig,axes=plt.subplots(1,2,figsize=(11,4),layout='constrained')
    for ax,run in zip(axes,RUNS):
        q=s[(s.run==run)&(s.scope=='ALL_CANDIDATES')&(s.rr==1.2)].set_index('category')
        matrix=np.array([[q.loc[r+'_'+p,'expectancy_r'] for p in POSITIONS[:3]] for r in REGIMES[:3]])
        im=ax.imshow(matrix,vmin=-1.2,vmax=1.2,cmap='RdYlGn');ax.set_xticks(range(3),POSITIONS[:3]);ax.set_yticks(range(3),REGIMES[:3]);ax.set_title(run)
        for i,r in enumerate(REGIMES[:3]):
            for j,p in enumerate(POSITIONS[:3]):
                v=q.loc[r+'_'+p];ax.text(j,i,f'{v.expectancy_r:+.2f}R\nn={int(v["count"])}' if v['count'] else 'n=0',ha='center',va='center')
    fig.colorbar(im,ax=list(axes),label='RR1.2 mean price R');fig.savefig(OUT/'regime_position.png',dpi=140);plt.close(fig)

if __name__=='__main__':main()
