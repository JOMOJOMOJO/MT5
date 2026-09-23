"""Descriptive frozen-bin research. No threshold search or trading-rule selection."""
import json,hashlib
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[2]/'reports/qa/three_wave/feature_research'
FEATURES=['ema20','ema_slope_atr','ema_deceleration','ema_distance_atr','adx14','plus_di','minus_di',
          'down_er','wave1_er','wave2_retracement','wave2_minutes','choch_break_strength']
MONTHS={'discovery':['2025-01','2025-02','2025-03'],'replication':['2025-05','2025-06','2025-07']}

def load(name,period):
    c=pd.read_csv(ROOT/name/'TW_features.csv')
    c['signal_dt']=pd.to_datetime(c.signal_time,format='%Y.%m.%d %H:%M:%S')
    c['month']=c.signal_dt.dt.strftime('%Y-%m')
    c=c.sort_values(['signal_time','id'])
    c['primary']=~c.duplicated(['parent','attempt','stage'])
    o=pd.read_csv(ROOT/name/'TW_feature_outcomes.csv')
    d=c.merge(o,on='id',validate='one_to_many',suffixes=('','_outcome'))
    d['period']=period
    d['closed']=d.outcome.isin(['TP','SL','TIMEOUT'])
    d['valid']=d.outcome!='INVALID_GEOMETRY'
    return d

def bootstrap(d,contrast=False):
    d=d[d.closed & d.result_R.notna()]
    if d.cluster_parent.nunique()<5:return (None,None)
    parents=sorted(d.cluster_parent.unique());rng=np.random.default_rng(20260923)
    weights=rng.multinomial(len(parents),np.ones(len(parents))/len(parents),size=1000)
    def resample(part):
        a=part.groupby('cluster_parent').result_R.agg(['sum','count']).reindex(parents,fill_value=0)
        numerator=weights@a['sum'].to_numpy();denom=weights@a['count'].to_numpy()
        return np.divide(numerator,denom,out=np.full(len(weights),np.nan),where=denom>0)
    v=resample(d[d.extreme=='high'])-resample(d[d.extreme=='low']) if contrast else resample(d)
    if not np.isfinite(v).any():return (None,None)
    return tuple(float(x) for x in np.nanquantile(v,[.025,.975]))

def metrics(d,period,ci=True):
    closed=d[d.closed]
    counts=d[d.valid].groupby('month').size().reindex(MONTHS[period],fill_value=0)
    parent_counts=d[d.valid].sort_values('signal_time').drop_duplicates('parent').groupby('month').size().reindex(MONTHS[period],fill_value=0)
    decision_counts=d[d.valid].groupby('month').signal_time.nunique().reindex(MONTHS[period],fill_value=0)
    lo,hi=bootstrap(d) if ci else (None,None)
    return dict(n=len(d),valid_candidates=int(d.valid.sum()),labeled_n=len(closed),parents=int(d.parent.nunique()),
        candidates_per_month=float(d.valid.sum()/3),min_month_candidates=int(counts.min()),
        monthly_counts=json.dumps(counts.to_dict(),sort_keys=True),
        parent_candidates_per_month=float(parent_counts.sum()/3),min_month_parents=int(parent_counts.min()),
        monthly_parent_counts=json.dumps(parent_counts.to_dict(),sort_keys=True),
        unique_decision_times=int(decision_counts.sum()),min_month_decision_times=int(decision_counts.min()),
        monthly_decision_counts=json.dumps(decision_counts.to_dict(),sort_keys=True),
        win_rate=float((closed.result_R>0).mean()) if len(closed) else None,
        expectancy_R=float(closed.result_R.mean()) if len(closed) else None,
        ci_low_R=lo,ci_high_R=hi,
        mfe_exit_R=float(closed.mfe_exit_R.mean()) if len(closed) else None,
        mae_exit_R=float(closed.mae_exit_R.mean()) if len(closed) else None,
        mfe60_R=float(d.mfe60_R.mean()) if d.mfe60_R.notna().any() else None,
        mae60_R=float(d.mae60_R.mean()) if d.mae60_R.notna().any() else None,
        complete60_n=int(d.complete60.sum()),timeouts=int((d.outcome=='TIMEOUT').sum()),
        censored=int((d.outcome=='END_CENSORED').sum()),invalid=int((d.outcome=='INVALID_GEOMETRY').sum()))

def main():
    full=pd.concat([load('discovery','discovery'),load('replication','replication')],ignore_index=True)
    full['cluster_parent']=''
    for period,d in full.groupby('period'):
        links={p:p for p in d.parent.unique()}
        def root(p):
            while links[p]!=p:p=links[p]
            return p
        for _,same in d.groupby('attempt'):
            ps=sorted(same.parent.unique())
            for p in ps[1:]:links[root(p)]=root(ps[0])
        full.loc[d.index,'cluster_parent']=[period+'_'+str(root(p)) for p in d.parent]
    full.to_csv(ROOT/'candidates_with_labels.csv',index=False)
    primary=full[full.primary].copy()
    diag=primary[primary.stop_basis=='STAGE'].copy()
    diag['down_span_minutes']=(pd.to_datetime(diag.m5_origin_time,format='%Y.%m.%d %H:%M:%S')-pd.to_datetime(diag.down_start,format='%Y.%m.%d %H:%M:%S'))/pd.Timedelta(minutes=1)
    diag['wave1_span_minutes']=(pd.to_datetime(diag.m5_high_time,format='%Y.%m.%d %H:%M:%S')-pd.to_datetime(diag.m5_origin_time,format='%Y.%m.%d %H:%M:%S'))/pd.Timedelta(minutes=1)
    diag[['id','period','stage','down_er','down_span_minutes','wave1_er','wave1_span_minutes']].to_csv(ROOT/'er_span_diagnostic.csv',index=False)
    discovery=primary[(primary.period=='discovery')&(primary.stop_basis=='STAGE')]
    edges={f:sorted(set(float(x) for x in discovery[f].dropna().quantile([.25,.5,.75]).to_numpy())) for f in FEATURES}
    top_bins={f:int(pd.cut(discovery[f],[-np.inf]+edges[f]+[np.inf],labels=False,include_lowest=True).max()) for f in FEATURES}
    prior=json.loads((ROOT/'frozen_bins_pre_analysis.json').read_text())
    assert edges==prior['edges'],'Frozen boundaries changed'
    (ROOT/'frozen_bins.json').write_text(json.dumps({'source':'discovery only, first candidate per parent/attempt/stage','edges':edges,
        'contrast_top_bin':top_bins,'note':'Top contrast bin is highest occupied discovery bin; bounded ER=1 can leave an empty overflow bin. All bins, including empty overflow, stay in tables.'},indent=2))
    all_stats=[];dist=[];bin_stats=[];monthly=[];contrasts=[]
    for (period,stage,basis),d in primary.groupby(['period','stage','stop_basis']):
        tags=dict(period=period,stage=stage,stop_basis=basis)
        all_stats.append(tags|metrics(d,period))
        for month in MONTHS[period]:
            m=d[d.month==month]
            monthly.append(tags|{'month':month,'candidates':len(m),'valid':int(m.valid.sum()),'labeled':int(m.closed.sum()),
                'unique_decision_times':int(m[m.valid].signal_time.nunique()),
                'expectancy_R':float(m[m.closed].result_R.mean()) if m.closed.any() else None})
        for f in FEATURES:
            v=d[f];z=d.copy();z['bin']=pd.cut(v,[-np.inf]+edges[f]+[np.inf],labels=False,include_lowest=True)
            for b in list(range(len(edges[f])+1))+['MISSING']:
                part=z[z.bin.isna()] if b=='MISSING' else z[z.bin==b]
                bin_stats.append(tags|{'feature':f,'bin':str(b),'lower':None if b=='MISSING' or b==0 else edges[f][b-1],
                    'upper':None if b=='MISSING' or b==len(edges[f]) else edges[f][b]}|metrics(part,period))
            wins=d[d.closed&(d.result_R>0)][f].dropna();losses=d[d.closed&(d.result_R<=0)][f].dropna()
            sd=np.sqrt((wins.var()+losses.var())/2)
            dist.append(tags|{'feature':f,'count':int(v.notna().sum()),'missing':int(v.isna().sum()),'mean':v.mean(),'std':v.std(),
                'min':v.min(),'q25':v.quantile(.25),'median':v.median(),'q75':v.quantile(.75),'max':v.max(),
                'winner_mean':wins.mean(),'nonwinner_mean':losses.mean(),'standardized_difference':(wins.mean()-losses.mean())/sd if sd>0 else None})
            z['extreme']=np.where(z.bin==0,'low',np.where(z.bin==top_bins[f],'high','middle'))
            extreme=z[z.extreme!='middle'];lo,hi=bootstrap(extreme,contrast=True)
            a=extreme[(extreme.extreme=='high')&extreme.closed].result_R
            b=extreme[(extreme.extreme=='low')&extreme.closed].result_R
            contrasts.append(tags|{'feature':f,'high_minus_low_R':a.mean()-b.mean(),'ci_low_R':lo,'ci_high_R':hi,'high_n':len(a),'low_n':len(b)})
    for name,records in [('stage_summary',all_stats),('feature_distributions',dist),('bin_statistics',bin_stats),('monthly_candidates',monthly),('feature_contrasts',contrasts)]:
        pd.DataFrame(records).to_csv(ROOT/(name+'.csv'),index=False)
    opportunities=[]
    for period,d in primary[primary.stop_basis=='STAGE'].groupby('period'):
        attempts=d.sort_values('signal_time').drop_duplicates(['parent','attempt'])
        parents=d.sort_values('signal_time').drop_duplicates('parent')
        for month in MONTHS[period]:
            opportunities.append({'period':period,'month':month,'distinct_attempts':int((attempts.month==month).sum()),'distinct_parents':int((parents.month==month).sum())})
    pd.DataFrame(opportunities).to_csv(ROOT/'distinct_opportunities.csv',index=False)
    bins=pd.DataFrame(bin_stats)
    a=bins[bins.period=='discovery'];b=bins[bins.period=='replication']
    joined=a.merge(b,on=['stage','stop_basis','feature','bin'],suffixes=('_discovery','_replication'))
    joined['positive_both']=(joined.expectancy_R_discovery>0)&(joined.expectancy_R_replication>0)
    joined['twenty_each_month_both']=(joined.min_month_candidates_discovery>=20)&(joined.min_month_candidates_replication>=20)
    joined['forty_each_month_both']=(joined.min_month_candidates_discovery>=40)&(joined.min_month_candidates_replication>=40)
    joined['twenty_unique_parents_each_month_both']=(joined.min_month_parents_discovery>=20)&(joined.min_month_parents_replication>=20)
    joined.to_csv(ROOT/'bin_replication.csv',index=False)
    # One clearly post-hoc frequency illustration for the requested NEXT experiment.
    # Uses an existing fixed Q4 edge; no search, no combinations, no execution change.
    hypothesis=[]
    for period,d in primary[(primary.stage=='CHOCH')&(primary.stop_basis=='STAGE')].groupby('period'):
        retained=d[d.choch_break_strength<=edges['choch_break_strength'][-1]]
        counts=retained.groupby('month').agg(candidates=('id','size'),unique_times=('signal_time','nunique'),unique_parents=('parent','nunique'))
        hypothesis.append({'period':period,'posthoc_hypothesis':'Exclude existing discovery Q4 of CHoCH break strength; not optimized or deployed',
            'fixed_boundary':edges['choch_break_strength'][-1],'n':len(retained),'mean_R':float(retained.result_R.mean()),'monthly':counts.to_dict(orient='index')})
    (ROOT/'next_hypothesis_frequency_only.json').write_text(json.dumps(hypothesis,indent=2))
    stable=joined[(joined.stop_basis=='STAGE')&joined.positive_both]
    (ROOT/'positive_bins.json').write_text(stable[['stage','feature','bin','n_discovery','n_replication','expectancy_R_discovery','expectancy_R_replication','min_month_candidates_discovery','min_month_candidates_replication','twenty_each_month_both']].to_json(orient='records',indent=2))
    fig,axes=plt.subplots(1,3,figsize=(15,5),sharey=True)
    contrasts=pd.DataFrame(contrasts)
    for ax,stage in zip(axes,['CHOCH','HL','READY']):
        for period,offset,color in [('discovery',-.13,'#2f6fa0'),('replication',.13,'#c37730')]:
            v=contrasts[(contrasts.stage==stage)&(contrasts.stop_basis=='STAGE')&(contrasts.period==period)].set_index('feature').reindex(FEATURES)
            y=np.arange(len(FEATURES))+offset
            for pos,(_,r) in zip(y,v.iterrows()):
                if pd.notna(r.ci_low_R):ax.plot([r.ci_low_R,r.ci_high_R],[pos,pos],color=color,alpha=.5,lw=1)
            ax.scatter(v.high_minus_low_R,y,color=color,s=18,label=period)
        ax.axvline(0,color='grey',ls=':');ax.set_title(stage);ax.set_xlabel('Top bin minus bottom bin expectancy R');ax.grid(alpha=.15)
    axes[0].set_yticks(range(len(FEATURES)),FEATURES);axes[0].invert_yaxis();axes[-1].legend()
    fig.suptitle('Descriptive contrasts with parent-cluster bootstrap 95% intervals; frozen discovery bins')
    fig.tight_layout();fig.savefig(ROOT/'feature_contrasts.png',dpi=150);plt.close(fig)
    for stage in ['CHOCH','HL','READY']:
        fig,axes=plt.subplots(3,4,figsize=(14,9))
        for ax,f in zip(axes.flat,FEATURES):
            for period,color in [('discovery','#2f6fa0'),('replication','#c37730')]:
                v=primary[(primary.stage==stage)&(primary.stop_basis=='STAGE')&(primary.period==period)][f].dropna().sort_values().to_numpy()
                if len(v):ax.step(v,np.arange(1,len(v)+1)/len(v),where='post',color=color,label=period)
            for edge in edges[f]:ax.axvline(edge,ls=':',lw=.6,color='grey',alpha=.6)
            ax.set_title(f,fontsize=10);ax.grid(alpha=.15);ax.set_ylim(0,1.02)
        axes[0,0].legend(fontsize=8);fig.suptitle(stage+' feature distributions (ECDF); vertical lines = frozen discovery bins')
        fig.tight_layout();fig.savefig(ROOT/('distributions_'+stage.lower()+'.png'),dpi=130);plt.close(fig)
    month_table=pd.DataFrame(monthly).query('stop_basis == "STAGE"').pivot(index='month',columns='stage',values='valid').sort_index()
    fig,ax=plt.subplots(figsize=(11,5));month_table[['CHOCH','HL','READY']].plot.bar(ax=ax)
    ax.axhline(20,color='black',ls='--',lw=1,label='20/month');ax.axhline(40,color='grey',ls=':',lw=1,label='40/month')
    ax.set_ylabel('First-stage candidates (stages overlap)');ax.set_title('Candidate frequency without entry filters');ax.legend();ax.tick_params(axis='x',rotation=0)
    fig.tight_layout();fig.savefig(ROOT/'monthly_candidates.png',dpi=140);plt.close(fig)
    print(pd.DataFrame(all_stats).query('stop_basis == "STAGE"')[['period','stage','n','valid_candidates','candidates_per_month','min_month_candidates','expectancy_R','ci_low_R','ci_high_R']].to_string(index=False))
    print('Positive bins in both periods:',len(stable),'meeting 20 each month:',int(stable.twenty_each_month_both.sum()))

if __name__=='__main__':main()
