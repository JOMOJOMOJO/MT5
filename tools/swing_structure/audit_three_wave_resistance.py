"""Audit every persisted resistance using closed M1 highs, independent of TF suffix logic."""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
from three_wave_resistance import History,seconds,ticks,SECONDS,TICK,HORIZONS
R=Path(__file__).resolve().parents[2];O=R/'reports/qa/three_wave/resistance_research';PREV=R/'reports/qa/three_wave/context_research'

def main():
    h=History(O)
    candidates=pd.concat([pd.read_csv(PREV/p/'TW_features.csv').assign(period=p) for p in ['discovery','replication','extension']],ignore_index=True)
    candidates['asof_sec']=seconds(candidates.signal_time);candidates=candidates.set_index(['period','id'])
    features=pd.read_csv(O/'resistance_features.csv').set_index(['period','id','stop_basis'])
    levels=pd.read_csv(O/'resistance_levels.csv');clusters=pd.read_csv(O/'resistance_clusters.csv')
    # One geometric level can appear in both stop-basis ledgers. Verify it once independently.
    unique=levels[levels.family!='RN'].drop_duplicates(['period','id','family','kind','price','bar_time'])
    checked=0
    for row in unique.itertuples():
        c=candidates.loc[(row.period,row.id)];tf=row.family;asof=int(c.asof_sec)
        bar=int(seconds(pd.Series([row.bar_time]))[0]);confirmation=int(seconds(pd.Series([row.confirmed_time]))[0])
        assert confirmation<=asof and ticks(row.price)>=ticks(c.entry_ask)
        a=np.searchsorted(h.t['M1'],bar+SECONDS[tf],side='left');b=np.searchsorted(h.t['M1']+60,asof,side='right')
        maximum=max(ticks(c.entry_bid),int(h.h['M1'][a:b].max()) if b>a else ticks(c.entry_bid))
        assert maximum<=ticks(row.price),('broken persisted resistance',row.id,tf,row.price)
        i=np.searchsorted(h.t[tf],bar);assert h.t[tf][i]==bar and h.h[tf][i]==ticks(row.price)
        if row.kind=='SWING':
            assert h.h[tf][i]>max(h.h[tf][i-2:i]) and h.h[tf][i]>max(h.h[tf][i+1:i+3])
            assert confirmation==h.t[tf][i+2]+SECONDS[tf]
            if tf=='M5':assert row.price>c.m5_high
        checked+=1
    rn=levels[levels.family=='RN'];assert np.allclose(rn.price*2,np.rint(rn.price*2),atol=1e-8,rtol=0)
    grouped_clusters={k:g for k,g in clusters.groupby(['period','id','stop_basis'])}
    count_checks=0
    for key,l in levels.groupby(['period','id','stop_basis']):
        f=features.loc[key];g=grouped_clusters.get(key,pd.DataFrame(columns=['first_R','low','high','levels','families']))
        assert np.isclose(l.price.min(),f.first_price,atol=1e-9,rtol=0)
        for bound in HORIZONS:
            tag=str(bound).replace('.','p');part=l[l.distance_R<=bound+1e-9]
            assert part.price.nunique()==f['resistance_count_'+tag]
            assert len(part[['price','family']].drop_duplicates())==f['source_count_'+tag]
            assert int((g.first_R<=bound+1e-9).sum())==f['cluster_count_'+tag]
            count_checks+=1
        for group in g.itertuples():
            assert ticks(group.high)-ticks(group.low)<=50
            members=l[(l.price>=group.low-1e-9)&(l.price<=group.high+1e-9)]
            assert members.family.nunique()>=2 and members.price.nunique()==group.levels
            assert '|'.join(sorted(members.family.unique()))==group.families
    baseline=json.loads((O/'baseline_manifest.json').read_text())
    unchanged={p:hashlib.sha256((R/p).read_bytes()).hexdigest()==v for p,v in baseline.items()}
    assert all(unchanged.values())
    if (O/'execution_ledger.csv').exists():
        ledger=pd.read_csv(O/'execution_ledger.csv');data=pd.read_csv(O/'candidates_with_resistance.csv')
        execution_checks=0
        for (period,stage,basis,feature,label),g in ledger.groupby(['period','stage','stop_basis','feature','label']):
            selected=g[g.accepted];d=data[(data.period==period)&(data.stage==stage)&(data.stop_basis==basis)]
            selected=d[d.id.isin(selected.id)].sort_values('entry_msc')
            assert not selected.parent.duplicated().any()
            for i in range(1,len(selected)):
                before=selected.iloc[i-1];now=selected.iloc[i]
                assert before.closed and now.entry_msc>=max(before.exit_msc,before.entry_msc+900000)
            if label.startswith('GE_'):assert (selected[feature]>=float(label[3:])-1e-10).all()
            execution_checks+=len(selected)
    else:execution_checks=0
    result={'passed':True,'independent_M1_unbroken_level_checks':checked,'count_checks':count_checks,
          'chronological_execution_checks':execution_checks,'baseline_unchanged':unchanged,
          'compile_clean':'Result: 0 errors, 0 warnings' in (O/'compile.log').read_text(encoding='utf-16')}
    assert result['compile_clean']
    (O/'independent_audit.json').write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='baseline_unchanged'}))
if __name__=='__main__':main()
