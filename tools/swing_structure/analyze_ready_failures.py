"""Fixed-entry descriptive failure study; no execution or parameter search."""
from pathlib import Path
import json,hashlib
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sklearn.impute import SimpleImputer
from sklearn.tree import DecisionTreeClassifier,export_text,plot_tree
from sklearn.metrics import balanced_accuracy_score,confusion_matrix
from analyze_normal_ready_m15 import markdown

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/three_wave/m15_normal_ready_ema_off'
OUT=ROOT/'reports/qa/three_wave/ready_failure_diagnostics'
PHASE=ROOT/'reports/qa/three_wave/m15_phase_research'
RUNS={'known_2025h1':'known_close_2025h1','known_2024q3':'holdout_close_2024q3'}
CLASSES=['WIN_1P2R','LOSS_NO_FOLLOWTHROUGH','LOSS_WEAK_FOLLOWTHROUGH','LOSS_ALMOST_TP','END_CENSORED']
TREE_FEATURES=['nearest_resistance_R','wave1_strength_atr','wave1_er','setup_age_minutes','wave2_retrace',
               'compression10','compression20','ready_return_high']
FOCUS=TREE_FEATURES[:-1]+['wave1_bullish_fraction','wave1_max_adverse_atr','m5_choch_break_atr',
                        'm5_wave1_distance_R','m15_structure_distance_R','window10_upper25_fraction',
                        'window20_failed_high_tests','window20_higher_lows','m15_raw_position']

def seconds(s):return int(pd.Timestamp(s).timestamp())
def div(a,b):return float(a/b) if np.isfinite(b) and b>0 else np.nan

def atr(b,n):
    h=b.high.to_numpy();l=b.low.to_numpy();c=b.close.to_numpy()
    prev=np.r_[c[0],c[:-1]];tr=np.maximum(h-l,np.maximum(abs(h-prev),abs(l-prev)))
    result=np.full(len(b),np.nan)
    if len(b)>=n:
        result[n-1]=tr[:n].mean()
        for i in range(n,len(b)):result[i]=(result[i-1]*(n-1)+tr[i])/n
    return result

def pivots(b,tf,side):
    x=b[side].to_numpy();t=b.bar.to_numpy();result=[]
    for i in range(2,len(b)-2):
        ok=(x[i]>max(x[i-2:i]) and x[i]>=max(x[i+1:i+3])) if side=='high' else (x[i]<min(x[i-2:i]) and x[i]<=min(x[i+1:i+3]))
        if ok:result.append((int(t[i]),int(t[i+2]+tf),float(x[i])))
    return np.array(result,dtype=float).reshape(-1,3)

def aggregate(m1,tf):
    return m1.assign(bar=m1.bar//tf*tf).groupby('bar',as_index=False).agg(open=('open','first'),high=('high','max'),low=('low','min'),close=('close','last'))

def prepare(m1,m15):
    m1=m1.copy();m5=aggregate(m1,300);m15=m15.copy()
    m1['atr5']=atr(m1,5);m5['atr14']=atr(m5,14)
    return dict(m1=m1,m5=m5,m15=m15,p1low=pivots(m1,60,'low'),p5high=pivots(m5,300,'high'),p15high=pivots(m15,900,'high'))

def resistance(p,b,tf,m1,m15,entry,cut,tp):
    start=int(b.bar.iloc[max(0,len(b)-800)])
    p=p[(p[:,0]>=start)&(p[:,1]<=cut)&(p[:,2]>entry)]
    t1=m1.bar.to_numpy();h1=np.maximum.accumulate(m1.high.to_numpy()[::-1])[::-1]
    t15=m15.bar.to_numpy();h15=np.maximum.accumulate(m15.high.to_numpy()[::-1])[::-1]
    available=[]
    for bar,confirmed,price in p:
        k=np.searchsorted(t1,bar+tf);mx=h1[k] if k<len(h1) else -np.inf
        if tf==900:
            j=np.searchsorted(t15,bar+tf);mx=max(mx,h15[j] if j<len(h15) else -np.inf)
        if mx<=price+1e-10:available.append((price,int(bar),int(confirmed)))
    available.sort()
    levels=[v[0] for v in available if v[0]<tp]
    first=available[0] if available else (np.nan,0,0)
    return first,levels,len(b)>=802,len(p),len(available)

def features(row,data):
    cut=int(row.entry_msc//1000);entry=float(row.entry);risk=float(row.risk)
    m1=data['m1'];m1=m1[m1.bar+60<=cut]
    m5=data['m5'];m5=m5[m5.bar+300<=cut]
    m15=data['m15'];m15=m15[m15.bar+900<=cut]
    a=float(m5.atr14.iloc[-1]);origin=seconds(row.m5_origin_time);top=seconds(row.m5_wave1_time)
    choch=seconds(row.m5_choch_time);ready=seconds(row.signal_time)
    assert seconds(row.m5_wave1_confirmed)<=cut and seconds(row.m5_origin_confirmed)<=cut
    assert m5[m5.bar.eq(origin)].low.iloc[0]==row.m5_origin
    assert abs(m5[m5.bar.eq(top)].high.iloc[0]-row.m5_wave1_high)<1e-8
    f={};meta={}
    width=row.m5_wave1_high-row.m5_origin
    f.update(m5_atr14_entry=a,m1_atr5_entry=float(m1.atr5.iloc[-1]))
    for name,level in [('m5_wave1',row.m5_wave1_high),('m15_structure',row.structure_high)]:
        delta=level-entry
        f[name+'_distance_price']=delta;f[name+'_distance_pips']=delta/0.01;f[name+'_distance_R']=delta/risk
    levels=[];nearest=[]
    for tf,b,p,name in [(300,m5,data['p5high'],'m5'),(900,m15,data['p15high'],'m15')]:
        first,upper,full,examined,alive=resistance(p,b,tf,m1,m15,entry,cut,row.tp)
        price,bar,confirmed=first
        f[name+'_nearest_resistance_R']=(price-entry)/risk
        f[name+'_resistance_count_before_tp']=len(upper)
        f[name+'_resistance_missing']=int(not np.isfinite(price))
        levels+=upper;nearest.append(price)
        meta.update({name+'_resistance_price':price,name+'_resistance_bar':bar,name+'_resistance_confirmed':confirmed,
                     name+'_resistance_full_800_bars':full,name+'_resistance_examined':examined,name+'_unbroken_count':alive})
        assert confirmed<=cut
    finite=[v for v in nearest if np.isfinite(v)]
    nr=min(finite) if finite else np.nan
    f['nearest_resistance_R']=(nr-entry)/risk
    f['resistance_before_tp']=int(np.isfinite(nr) and nr<row.tp)
    f['resistance_before_nominal_1p2R']=int(np.isfinite(nr) and (nr-entry)/risk<1.2)
    f['resistance_missing']=int(not finite)
    f['resistance_count_before_tp']=len(levels)
    f['unique_resistance_prices_before_tp']=len(set(round(v,3) for v in levels))
    w=m5[(m5.bar>=origin)&(m5.bar<=top)]
    path=np.r_[row.m5_origin,w.loc[w.bar<top,'close'].to_numpy(),row.m5_wave1_high]
    cp=w.close.to_numpy()
    f.update(wave1_range_price=width,wave1_range_pips=width/0.01,wave1_strength_atr=div(width,a),
        wave1_minutes=(top-origin)/60,wave1_er=div(abs(path[-1]-path[0]),np.abs(np.diff(path)).sum()),
        wave1_close_er=div(abs(cp[-1]-cp[0]),np.abs(np.diff(cp)).sum()),
        wave1_bullish_fraction=float((w.close>w.open).mean()),
        wave1_max_adverse_atr=div(np.max(np.maximum.accumulate(path)-path),a))
    cb=m5[m5.bar+300==choch];assert len(cb)==1
    f['m5_choch_break_atr']=div(float(cb.close.iloc[0])-row.m5_return_high,a)
    after=m1[m1.bar>=top+300]
    pull=max(0,float(row.m5_wave1_high-after.low.min())) if len(after) else 0
    f.update(setup_age_minutes=(ready-top)/60,m5_choch_to_ready_minutes=(ready-choch)/60,
             wave1_high_to_entry_minutes=(row.entry_msc/1000-top)/60,
             wave2_retrace=div(pull,width),wave2_max_pullback_atr=div(pull,a),
             wave2_m5_bars=int((m5.bar>top).sum()),ready_return_high=int(row.early_break),
             m15_raw_position=float(row.raw_position),m15_minutes_since_break=float(row.minutes_since_break))
    pl=data['p1low'];pl=pl[pl[:,1]<=cut]
    for n in [10,20]:
        end=cut//60*60;w=m1[(m1.bar>=end-n*60)&(m1.bar<end)]
        prev=m1[(m1.bar>=end-2*n*60)&(m1.bar<end-n*60)]
        meta[f'window{n}_bars']=len(w);meta[f'window{n}_previous_bars']=len(prev)
        pre=f'window{n}_'
        keys=['range_atr','envelope_shrink','upper25_fraction','latest_high_pullback_atr','higher_lows','lower_lows','new_highs','failed_high_tests','mean_bar_range','atr5']
        for key in keys:f[pre+key]=np.nan
        f['compression'+str(n)]=np.nan
        if len(w)!=n:continue
        h=w.high.to_numpy();l=w.low.to_numpy();c=w.close.to_numpy();rng=h.max()-l.min()
        latest=np.where(h==h.max())[0][-1]
        dd=max(0,h[latest]-l[latest+1:].min()) if latest+1<n else 0
        priorhigh=np.maximum.accumulate(h)[:-1]
        lows=[i for i in range(1,len(pl)) if pl[i,0]>=end-n*60 and pl[i,0]<end]
        f.update({pre+'range_atr':div(rng,a),pre+'upper25_fraction':float(np.mean(c>=l.min()+0.75*rng)),
                  pre+'latest_high_pullback_atr':div(dd,a),pre+'higher_lows':sum(pl[i,2]>pl[i-1,2] for i in lows),
                  pre+'lower_lows':sum(pl[i,2]<pl[i-1,2] for i in lows),pre+'new_highs':int(np.sum(h[1:]>priorhigh)),
                  pre+'failed_high_tests':int(np.sum((h[1:]>=priorhigh)&(c[1:]<=priorhigh))),
                  pre+'mean_bar_range':float(np.mean(h-l)),pre+'atr5':float(w.atr5.iloc[-1])})
        if len(prev)==n:
            f['compression'+str(n)]=div(np.sum(h-l),float((prev.high-prev.low).sum()))
            f[pre+'envelope_shrink']=div(rng,float(prev.high.max()-prev.low.min()))
    meta['latest_m1_closed']=int(m1.bar.iloc[-1]+60);meta['latest_m5_closed']=int(m5.bar.iloc[-1]+300)
    meta['latest_m15_closed']=int(m15.bar.iloc[-1]+900)
    assert max(meta[k] for k in ['latest_m1_closed','latest_m5_closed','latest_m15_closed'])<=cut
    return f,meta

def label(r):
    if r.outcome=='TP':return 'WIN_1P2R'
    if r.outcome!='SL':return 'END_CENSORED'
    if r.mfe_to_exit<0.3:return 'LOSS_NO_FOLLOWTHROUGH'
    if r.mfe_to_exit<0.8:return 'LOSS_WEAK_FOLLOWTHROUGH'
    if r.mfe_to_exit<1.2:return 'LOSS_ALMOST_TP'
    return 'LOSS_AT_OR_ABOVE_1P2R_CHECK'

def describe(x):
    y=x.dropna().astype(float)
    return dict(n=len(y),missing=int(x.isna().sum()),mean=y.mean(),median=y.median(),q25=y.quantile(.25),q75=y.quantile(.75))

def performance(g):
    r=g.result_r.dropna();neg=-r[r<0].sum()
    return dict(n=len(g),closed=len(r),parent_n=g.parent_id.nunique(),win_rate=(r>0).mean(),expectancy_r=r.mean(),
                pf=r[r>0].sum()/neg if neg>0 else np.nan,mfe=g.loc[g.result_r.notna(),'mfe_to_exit'].mean(),
                mae=g.loc[g.result_r.notna(),'mae_to_exit'].mean())

def load():
    x=pd.read_csv(BASE/'shadow_candidates_with_context.csv')
    sig=pd.read_csv(BASE/'ready_candidates_with_context.csv')
    cols=['run','signal_id','signal_time','early_break','state_transition_reason','m5_origin','m5_origin_time','m5_origin_confirmed',
          'm5_return_high','m5_choch_time','m5_wave1_high','m5_wave1_time','m5_wave1_confirmed']
    x=x.merge(sig[cols],on=['run','signal_id'],validate='one_to_one')
    x['outcome_class']=x.apply(label,axis=1)
    x['mfe_R']=x.mfe_to_exit;x['mae_R']=x.mae_to_exit
    assert x.outcome_class.isin(CLASSES).all()
    x['ready_type']=np.where(x.early_break,'READY_RETURN_HIGH','READY_WAVE1_HIGH')
    assert x.state_transition_reason.eq(np.where(x.early_break,'WAVE2_RETURN_HIGH_CLOSE_BREAK','WAVE1_HIGH_CLOSE_BREAK')).all()
    x['parent_id']=x.run+'/'+x.signal_id.str.split('/').str[0]
    datasets={};audit={};allf=[];allmeta=[]
    for run,old in RUNS.items():
        m1=pd.read_csv(PHASE/old/'MP_m1.csv').rename(columns={'time':'bar'})
        m15=pd.read_csv(PHASE/old/'MP_phases.csv')[['bar','open','high','low','close']]
        assert not m1.bar.duplicated().any() and not m15.bar.duplicated().any()
        res=aggregate(m1,900);match=m15.merge(res,on='bar',suffixes=('_native','_m1'))
        match=match[(match.bar>=m1.bar.min())&(match.bar+900<=m1.bar.max()+60)]
        differences={v:int((abs(match[v+'_native']-match[v+'_m1'])>1e-8).sum()) for v in ['open','high','low','close']}
        assert all(differences[v]==0 for v in ['high','low','close'])
        differences_table=match[np.any(np.column_stack([abs(match[v+'_native']-match[v+'_m1'])>1e-8 for v in ['open','high','low','close']]),axis=1)]
        differences_table.to_csv(OUT/(run+'_bar_source_differences.csv'),index=False)
        d=prepare(m1,m15);datasets[run]=(m1,m15,d)
        audit[run]=dict(m1_rows=len(m1),m15_matched_rows=len(match),m15_difference_counts=differences)
    for _,r in x.iterrows():
        f,meta=features(r,datasets[r.run][2]);allf.append(f);allmeta.append(meta)
    feature_names=list(allf[0]);x=pd.concat([x.reset_index(drop=True),pd.DataFrame(allf),pd.DataFrame(allmeta)],axis=1)
    # Exact prefix and future-OHLC mutation audits across both periods.
    tested=[]
    for run,(m1,m15,d) in datasets.items():
        q=x[x.run.eq(run)];ix=sorted(set([0,len(q)//3,2*len(q)//3,len(q)-1]))
        for j in ix:
            r=q.iloc[j];cut=int(r.entry_msc//1000)
            f,_=features(r,d)
            short=prepare(m1[m1.bar+60<=cut],m15[m15.bar+900<=cut]);g,_=features(r,short)
            np.testing.assert_allclose(list(f.values()),list(g.values()),rtol=0,atol=1e-12,equal_nan=True)
            a=m1.copy();b=m15.copy()
            for v in ['open','high','low','close']:
                a.loc[a.bar+60>cut,v]+=100;b.loc[b.bar+900>cut,v]+=100
            z,_=features(r,prepare(a,b))
            np.testing.assert_allclose(list(f.values()),list(z.values()),rtol=0,atol=1e-12,equal_nan=True)
            tested.append(r.signal_id)
    audit['causal_prefix_and_future_mutation']=dict(candidates=len(tested),ids=tested,result='PASS')
    audit['m5_anchor_prices']='ALL_MATCH';audit['entry_ohlc_limits']='ALL_AT_OR_BEFORE_ENTRY'
    return x,feature_names,audit

def tables(x,columns):
    allstats=[];period=[]
    for run in ['ALL_PERIODS',*RUNS]:
        z=x if run=='ALL_PERIODS' else x[x.run.eq(run)]
        for outcome in CLASSES:
            g=z[z.outcome_class.eq(outcome)]
            for f in columns:
                row=dict(run=run,outcome_class=outcome,feature=f,parent_n=g.parent_id.nunique(),**describe(g[f]))
                (allstats if run=='ALL_PERIODS' else period).append(row)
    pd.DataFrame(allstats).to_csv(OUT/'outcome_feature_statistics.csv',index=False)
    per=pd.DataFrame(period);per.to_csv(OUT/'period_feature_statistics.csv',index=False)
    directions=[]
    for f in columns:
        for outcome in CLASSES[1:4]:
            row=dict(feature=f,loss_class=outcome)
            for run,tag in [('known_2025h1','2025'),('known_2024q3','2024')]:
                a=per[per.run.eq(run)&per.feature.eq(f)&per.outcome_class.eq(outcome)].iloc[0]
                b=per[per.run.eq(run)&per.feature.eq(f)&per.outcome_class.eq('WIN_1P2R')].iloc[0]
                row['loss_n_'+tag]=int(a.n);row['win_n_'+tag]=int(b.n);row['loss_minus_win_median_'+tag]=a['median']-b['median']
            d1=row['loss_minus_win_median_2025'];d2=row['loss_minus_win_median_2024']
            enough=min(row['loss_n_2025'],row['win_n_2025'],row['loss_n_2024'],row['win_n_2024'])>=5
            row['status']='INSUFFICIENT_N' if not enough else ('SAME_DIRECTION' if np.sign(d1)==np.sign(d2) and d1*d2>0 else 'NOT_REPLICATED')
            directions.append(row)
    pd.DataFrame(directions).to_csv(OUT/'period_direction_comparison.csv',index=False)
    rt=[];counts=[];env=[]
    for run in ['ALL_PERIODS',*RUNS]:
        z=x if run=='ALL_PERIODS' else x[x.run.eq(run)]
        for ready in ['READY_RETURN_HIGH','READY_WAVE1_HIGH']:
            g=z[z.ready_type.eq(ready)];rt.append(dict(run=run,ready_type=ready,**performance(g)))
        for outcome in CLASSES:
            g=z[z.outcome_class.eq(outcome)];counts.append(dict(run=run,outcome_class=outcome,n=len(g),parents=g.parent_id.nunique()))
        for category in sorted(x.category.unique()):
            g=z[z.category.eq(category)]
            for outcome in CLASSES:env.append(dict(run=run,category=category,outcome_class=outcome,n=int(g.outcome_class.eq(outcome).sum()),category_n=len(g)))
    pd.DataFrame(rt).to_csv(OUT/'ready_type_statistics.csv',index=False)
    pd.DataFrame(counts).to_csv(OUT/'outcome_counts.csv',index=False)
    pd.DataFrame(env).to_csv(OUT/'m15_outcome_statistics.csv',index=False)
    high=[]
    for run in ['ALL_PERIODS',*RUNS]:
        z=x[x.position.eq('HIGH')]
        if run!='ALL_PERIODS':z=z[z.run.eq(run)]
        for outcome in CLASSES:
            for f in columns:
                g=z[z.outcome_class.eq(outcome)]
                high.append(dict(run=run,outcome_class=outcome,feature=f,**describe(g[f])))
    pd.DataFrame(high).to_csv(OUT/'high_position_feature_statistics.csv',index=False)

def trees(x):
    z=x[x.outcome_class.ne('END_CENSORED')].copy();reports=[];metrics=[]
    cases=[('ALL_DESCRIPTIVE',z,None),('FIT_2025_CHECK_2024',z[z.run.eq('known_2025h1')],z[z.run.eq('known_2024q3')]),
           ('FIT_2024_CHECK_2025',z[z.run.eq('known_2024q3')],z[z.run.eq('known_2025h1')])]
    leaves=[]
    for name,train,test in cases:
        imp=SimpleImputer(strategy='median',add_indicator=True)
        a=imp.fit_transform(train[TREE_FEATURES]);names=imp.get_feature_names_out(TREE_FEATURES).tolist()
        tree=DecisionTreeClassifier(max_depth=2,min_samples_leaf=15,random_state=0,class_weight=None)
        tree.fit(a,train.outcome_class)
        reports += [name,f'Train n={len(train)}, max_depth=2, min_samples_leaf=15, no threshold search.',export_text(tree,feature_names=names,decimals=4)]
        leaf=tree.apply(a)
        for n in np.unique(leaf):
            g=train[leaf==n];leaves.append(dict(model=name,leaf=int(n),**performance(g),**g.outcome_class.value_counts().to_dict()))
        if test is not None:
            pred=tree.predict(imp.transform(test[TREE_FEATURES]));major=train.outcome_class.mode().iloc[0]
            score=balanced_accuracy_score(test.outcome_class,pred);baseline=balanced_accuracy_score(test.outcome_class,np.repeat(major,len(test)))
            metrics.append(dict(model=name,train_n=len(train),check_n=len(test),balanced_accuracy=score,majority_balanced_accuracy=baseline))
            reports += [f'Known-period cross-check balanced accuracy={score:.4f}, majority={baseline:.4f}',
                        'Confusion rows=true columns=predicted: '+str(CLASSES[:4]),str(confusion_matrix(test.outcome_class,pred,labels=CLASSES[:4]))]
        if name=='ALL_DESCRIPTIVE':
            fig,ax=plt.subplots(figsize=(17,8));plot_tree(tree,feature_names=names,class_names=list(tree.classes_),filled=True,ax=ax,fontsize=8)
            fig.tight_layout();fig.savefig(OUT/'decision_tree.png',dpi=150);plt.close(fig)
    (OUT/'decision_tree_diagnostic.txt').write_text('\n\n'.join(reports)+'\n\nDescriptive only. Known periods, not OOS. Rules are not trading filters.\n',encoding='utf-8')
    pd.DataFrame(metrics).to_csv(OUT/'decision_tree_cross_period.csv',index=False)
    pd.DataFrame(leaves).to_csv(OUT/'decision_tree_leaves.csv',index=False)

def plots(x):
    colors=['#2ca25f','#de2d26','#fd8d3c','#756bb1']
    short=['WIN','NO_FOLLOW','WEAK','ALMOST_TP']
    for page,features_ in enumerate([FOCUS[:8],FOCUS[8:]]):
        fig,axs=plt.subplots(2,4,figsize=(19,10));axs=axs.ravel()
        for ax,f in zip(axs,features_):
            for i,(label_,color) in enumerate(zip(CLASSES[:4],colors)):
                vals=x.loc[x.outcome_class.eq(label_),f].dropna().to_numpy()
                if len(vals):
                    ax.boxplot(vals,positions=[i],widths=.55,showfliers=False,patch_artist=True,boxprops=dict(facecolor=color,alpha=.3))
                    ax.scatter(i+np.linspace(-.15,.15,len(vals)),vals,s=8,color=color,alpha=.55)
            ax.set_xticks(range(4),short,rotation=18);ax.set_title(f,fontsize=10);ax.grid(axis='y',alpha=.2)
        for ax in axs[len(features_):]:ax.set_visible(False)
        fig.suptitle('Fixed READY: entry-time features by post-entry outcome (all points; no threshold tuning)')
        fig.tight_layout();fig.savefig(OUT/f'feature_distributions_{page+1}.png',dpi=150);plt.close(fig)
    fig,axs=plt.subplots(2,3,figsize=(17,9))
    for ax,f in zip(axs.ravel(),FOCUS[:6]):
        for run,style in [('known_2025h1','-'),('known_2024q3','--')]:
            for label_,color in zip(CLASSES[:4],colors):
                v=np.sort(x.loc[x.run.eq(run)&x.outcome_class.eq(label_),f].dropna())
                if len(v):ax.step(v,np.arange(1,len(v)+1)/len(v),where='post',color=color,linestyle=style,label=run[-6:]+' '+label_)
        ax.set_title(f);ax.set_ylabel('Empirical cumulative fraction');ax.grid(alpha=.2)
    handles,labels=axs[0,0].get_legend_handles_labels();fig.legend(handles,labels,loc='lower center',ncol=4,fontsize=8)
    fig.tight_layout(rect=(0,.09,1,1));fig.savefig(OUT/'period_feature_ecdf.png',dpi=150);plt.close(fig)

def main():
    OUT.mkdir(exist_ok=True,parents=True)
    x,columns,audit=load()
    x.to_csv(OUT/'ready_failure_analysis.csv',index=False)
    (OUT/'feature_columns.json').write_text(json.dumps(columns,indent=2))
    tables(x,columns);trees(x);plots(x)
    audit['rows']=len(x);audit['parents']=x.parent_id.nunique();audit['outcomes']=x.outcome_class.value_counts().to_dict()
    h=json.loads((OUT/'production_hashes_before.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==v for p,v in h.items())
    original=pd.read_csv(BASE/'shadow_candidates_with_context.csv')
    for c in ['entry_msc','entry','sl','tp','risk','outcome','result_r','mfe_to_exit','mae_to_exit']:
        pd.testing.assert_series_equal(x[c].reset_index(drop=True),original[c].reset_index(drop=True))
    audit['original_entries_labels_unchanged']=True;audit['production_unchanged']=True
    (OUT/'audit.json').write_text(json.dumps(audit,indent=2))
    print(json.dumps(audit,indent=2))

if __name__=='__main__':main()
