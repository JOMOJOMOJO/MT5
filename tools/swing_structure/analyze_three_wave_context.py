"""Fixed HTF regime cross-tabs and chronological capacity replay. No optimization."""
from pathlib import Path
from itertools import product
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
R=Path(__file__).resolve().parents[2]
ROOT=R/'reports/qa/three_wave/context_research'
PERIODS={'discovery':['2025-01','2025-02','2025-03'],'replication':['2025-05','2025-06','2025-07'],
         'extension':['2025-08','2025-09','2025-10']}
CELLS=[a+' / '+b for a,b in product(['UP','RANGE','DOWN'],repeat=2)]+['UNKNOWN']
FMT='%Y.%m.%d %H:%M:%S'

def load(period):
    p=ROOT/period;c=pd.read_csv(p/'TW_features.csv').sort_values(['signal_time','id'])
    c['primary']=~c.duplicated(['parent','attempt','stage'])
    x=pd.read_csv(p/'TW_context.csv')
    for tf in ['H1','M15']:
        part=x[x.tf==tf].drop(columns='tf').set_index('id').add_prefix(tf.lower()+'_')
        c=c.join(part,on='id',validate='one_to_one')
    d=c.merge(pd.read_csv(p/'TW_feature_outcomes.csv'),on='id',validate='one_to_many')
    d['period']=period;d['month']=pd.to_datetime(d.signal_time,format=FMT).dt.strftime('%Y-%m')
    d['cell']=d.h1_regime+' / '+d.m15_regime
    d.loc[(d.h1_regime=='UNKNOWN')|(d.m15_regime=='UNKNOWN'),'cell']='UNKNOWN'
    d['closed']=d.outcome.isin(['SL','TP','TIMEOUT']);d['valid']=d.outcome!='INVALID_GEOMETRY'
    for tf in ['h1','m15']:d[tf+'_room_R']=d[tf+'_room_price']/d.risk
    # Merge parents sharing an M1 attempt for uncertainty calculations.
    links={p:p for p in d.parent.unique()}
    def root(p):
        while links[p]!=p:p=links[p]
        return p
    for _,group in d.groupby('attempt'):
        ps=sorted(group.parent.unique())
        for p in ps[1:]:links[root(p)]=root(ps[0])
    d['cluster']=[root(p) for p in d.parent]
    return d

def replay(d):
    """No outcome-based candidate choice: only occupied/cooldown/used-parent state."""
    if d.empty:return pd.DataFrame(columns=['id','reason','accepted']).astype({'accepted':bool})
    busy_until=-1;cooldown_until=-1;used=set();records=[]
    for row in d.sort_values(['entry_msc','parent','id'],ascending=[True,False,True]).itertuples():
        now=row.entry_msc
        if not row.valid:reason='INVALID_GEOMETRY'
        elif row.parent in used:reason='PARENT_ALREADY_FILLED'
        elif now<busy_until:reason='POSITION_OPEN'
        elif now<cooldown_until:reason='COOLDOWN_FROM_FILL'
        else:
            reason='ACCEPTED';used.add(row.parent);cooldown_until=now+900000
            busy_until=row.exit_msc if row.closed else float('inf')
        records.append({'id':row.id,'reason':reason,'accepted':reason=='ACCEPTED'})
    return pd.DataFrame(records,columns=['id','reason','accepted']).astype({'accepted':bool})

def unit_replay():
    empty=replay(pd.DataFrame());assert empty[empty.accepted].empty and 'id' in empty[empty.accepted].columns
    rows=[]
    for id,t,exit,parent,closed,valid in [('a',0,1200000,1,True,True),('b',960000,1000000,2,True,True),
            ('c',1200000,1260000,2,True,True),('d',1300000,1350000,3,True,True),
            ('e',2100000,2150000,2,True,True),('f',2100000,0,4,False,True),('g',999999999,0,5,True,True)]:
        rows.append(dict(id=id,entry_msc=t,exit_msc=exit,parent=parent,closed=closed,valid=valid))
    q=replay(pd.DataFrame(rows)).set_index('id')
    assert q.loc['a','accepted'] and q.loc['c','accepted'] and q.loc['f','accepted']
    assert q.loc['b','reason']=='POSITION_OPEN' and q.loc['d','reason']=='COOLDOWN_FROM_FILL'
    assert q.loc['e','reason']=='PARENT_ALREADY_FILLED' and q.loc['g','reason']=='POSITION_OPEN'
    # Exactly the cooldown boundary is allowed; simultaneous candidates pick newest parent.
    z=pd.DataFrame([dict(id='invalid',entry_msc=0,exit_msc=1,parent=9,closed=False,valid=False),
       dict(id='x',entry_msc=0,exit_msc=1,parent=1,closed=True,valid=True),
       dict(id='y',entry_msc=900000,exit_msc=900001,parent=2,closed=True,valid=True),
       dict(id='z',entry_msc=900000,exit_msc=900001,parent=3,closed=True,valid=True)])
    q=replay(z).set_index('id');assert q.loc['z','accepted'] and not q.loc['y','accepted']
    assert q.loc['invalid','reason']=='INVALID_GEOMETRY' and q.loc['x','accepted']
    return {'passed':True,'cases':['position longer than cooldown','cooldown from entry','one fill per parent',
             'censored position stays occupied','exact cooldown boundary','newest parent tie priority',
             'empty environment cell','invalid geometry does not occupy']}

def interval(d):
    z=d[d.closed].groupby('cluster').result_R.agg(['sum','count'])
    if len(z)<5:return np.nan,np.nan
    w=np.random.default_rng(20260923).multinomial(len(z),np.full(len(z),1/len(z)),size=1000)
    return np.quantile((w@z['sum'].to_numpy())/(w@z['count'].to_numpy()),[.025,.975])

def contrast_interval(d,cell):
    """Cell minus other environments, resampling the same parent clusters jointly."""
    d=d[d.closed];parents=sorted(d.cluster.unique())
    a=d[d.cell==cell];b=d[d.cell!=cell]
    if a.cluster.nunique()<5 or b.cluster.nunique()<5:return np.nan,np.nan
    weights=np.random.default_rng(20260923).multinomial(len(parents),np.full(len(parents),1/len(parents)),size=1000)
    def means(part):
        z=part.groupby('cluster').result_R.agg(['sum','count']).reindex(parents,fill_value=0)
        denominator=weights@z['count'].to_numpy();numerator=weights@z['sum'].to_numpy()
        return np.divide(numerator,denominator,out=np.full(1000,np.nan),where=denominator>0)
    return np.nanquantile(means(a)-means(b),[.025,.975])

def metrics(d,period):
    z=d[d.closed];counts=d[d.valid].groupby('month').size().reindex(PERIODS[period],fill_value=0)
    lo,hi=interval(d)
    return {'n':len(d),'parents':d.parent.nunique(),'unique_times':d.signal_time.nunique(),'closed_n':len(z),
       'win_rate':(z.result_R>0).mean(),'expectancy_R':z.result_R.mean(),'ci_low_R':lo,'ci_high_R':hi,
       'mfe_exit_R':z.mfe_exit_R.mean(),'mae_exit_R':z.mae_exit_R.mean(),
       'mfe60_R':d.mfe60_R.mean(),'mae60_R':d.mae60_R.mean(),
       'min_month':int(counts.min()),'mean_month':float(counts.mean()),'max_month':int(counts.max()),
       'monthly_counts':json.dumps({k:int(v) for k,v in counts.items()}),
       'timeouts':int((d.outcome=='TIMEOUT').sum()),'censored':int((d.outcome=='END_CENSORED').sum()),
       'invalid':int((~d.valid).sum())}

def main():
    (ROOT/'replay_unit.json').write_text(json.dumps(unit_replay(),indent=2))
    periods=[p for p in PERIODS if (ROOT/p/'context_audit.json').exists()]
    for p in periods:assert json.loads((ROOT/p/'context_audit.json').read_text())['passed'],p
    full=pd.concat([load(p) for p in periods],ignore_index=True)
    full.to_csv(ROOT/'candidates_with_context.csv',index=False)
    primary=full[full.primary].copy();stats=[];monthly=[];ledger=[];descriptive=[];singles=[];effects=[]
    for (period,stage,basis),d in primary.groupby(['period','stage','stop_basis']):
        tags=dict(period=period,stage=stage,stop_basis=basis)
        trace=replay(d);executed=d.merge(trace[trace.accepted][['id']],on='id',validate='one_to_one')
        ledger.append(trace.assign(**tags,replay='UNFILTERED'))
        for cell in ['ALL']+CELLS:
            part=d if cell=='ALL' else d[d.cell==cell]
            global_part=executed if cell=='ALL' else executed[executed.cell==cell]
            if cell!='ALL':
                lo,hi=contrast_interval(d,cell)
                other=d[(d.cell!=cell)&d.closed];this=part[part.closed]
                effects.append(tags|dict(cell=cell,n=len(this),other_n=len(other),
                    cell_minus_other_R=this.result_R.mean()-other.result_R.mean(),ci_low_R=lo,ci_high_R=hi))
            alone=replay(part);isolated=part.merge(alone[alone.accepted][['id']],on='id',validate='one_to_one')
            if cell!='ALL':ledger.append(alone.assign(**tags,replay=cell))
            for mode,z in [('CANDIDATES',part),('UNFILTERED_ACCEPTED',global_part),('CELL_ONLY_CAPACITY',isolated)]:
                stats.append(tags|dict(cell=cell,mode=mode)|metrics(z,period))
                for month in PERIODS[period]:
                    m=z[z.month==month];closed=m[m.closed]
                    monthly.append(tags|dict(cell=cell,mode=mode,month=month,n=len(m),parents=m.parent.nunique(),
                       expectancy_R=closed.result_R.mean(),win_rate=(closed.result_R>0).mean()))
            for tf in ['h1','m15']:
                for feature in ['position','room_R','ema_slope_atr']:
                    v=part[tf+'_'+feature]
                    descriptive.append(tags|dict(cell=cell,feature=tf+'_'+feature,n=v.notna().sum(),missing=v.isna().sum(),
                         mean=v.mean(),q25=v.quantile(.25),median=v.median(),q75=v.quantile(.75)))
        # Marginal regime summaries and fixed single-context buckets. No cross-feature ANDs.
        for tf in ['h1','m15']:
            for field in ['regime','position','room_R','ema_slope_atr']:
                feature=tf+'_'+field;v=d[feature]
                if field=='regime':labels=['UP','RANGE','DOWN','UNKNOWN'];b=v
                elif field=='position':
                    labels=['BELOW_LOW','LOWER_HALF','UPPER_HALF','ABOVE_HIGH','MISSING']
                    b=pd.Series(np.select([v<0,v<=.5,v<=1,v>1],labels[:4],default='MISSING'),index=d.index)
                elif field=='room_R':
                    labels=['AT_OR_ABOVE_HIGH','LT_1R','1_TO_2R','GE_2R','MISSING']
                    b=pd.Series(np.select([v<=0,v<1,v<2,v>=2],labels[:4],default='MISSING'),index=d.index)
                else:
                    labels=['NEGATIVE','ZERO','POSITIVE','MISSING']
                    b=pd.Series(np.select([v<0,v==0,v>0],labels[:3],default='MISSING'),index=d.index)
                for label in labels:singles.append(tags|dict(feature=feature,bucket=label)|metrics(d[b==label],period))
    tables={'regime_statistics':stats,'monthly_counts':monthly,'context_distributions':descriptive,'single_context_buckets':singles,
            'regime_vs_other_intervals':effects}
    for name,rows in tables.items():pd.DataFrame(rows).to_csv(ROOT/(name+'.csv'),index=False)
    pd.concat(ledger,ignore_index=True).to_csv(ROOT/'execution_ledger.csv',index=False)
    # Explicitly post-hoc interpretation, NOT another optimized replay or deployed filter.
    # Subtract the observed weak cell from already feasible entries; do not replace entries.
    hyp=[];traces=pd.concat(ledger,ignore_index=True)
    eligible=primary[(primary.stage=='CHOCH')&(primary.stop_basis=='STAGE')]
    accepted=traces[(traces.stage=='CHOCH')&(traces.stop_basis=='STAGE')&(traces.replay=='UNFILTERED')&traces.accepted]
    for period,g in eligible.groupby('period'):
        bad=g[g.cell=='RANGE / DOWN'];other=g[g.cell!='RANGE / DOWN']
        subset=g.merge(accepted[accepted.period==period][['id']],on='id')
        subset=subset[subset.cell!='RANGE / DOWN']
        counts=subset.groupby('month').size().reindex(PERIODS[period],fill_value=0)
        hyp.append({'period':period,'bad_n':len(bad),'bad_R':bad.result_R.mean(),'other_n':len(other),'other_R':other.result_R.mean(),
          'unchanged_accepted_subset_R':subset.result_R.mean(),'unchanged_accepted_subset_monthly':{k:int(v) for k,v in counts.items()}})
    diagnostic={'status':'Post-hoc interpretation of existing group comparison, not a deployed filter or a newly optimized entry rule',
       'hypothesis':'CHOCH in H1 RANGE / M15 DOWN may be an environment to avoid',
       'capacity_method':'Subtract this cell from already accepted unfiltered entries only; no replacement entries replayed. Remaining entries are still feasible under the same constraints.',
       'results':hyp}
    (ROOT/'next_hypothesis_diagnostic.json').write_text(json.dumps(diagnostic,indent=2))
    s=pd.DataFrame(stats);base=s[s.cell=='ALL'][['period','stage','stop_basis','mode','expectancy_R']].rename(columns={'expectancy_R':'stage_mean_R'})
    contrast=s[s.cell!='ALL'].merge(base,on=['period','stage','stop_basis','mode'])
    contrast['cell_minus_stage_R']=contrast.expectancy_R-contrast.stage_mean_R
    contrast.to_csv(ROOT/'regime_contrasts.csv',index=False)
    keys=['stage','stop_basis','mode','cell'];wide=None
    for period in periods:
        z=s[s.period==period].drop(columns='period').set_index(keys).add_suffix('_'+period)
        wide=z if wide is None else wide.join(z,how='outer')
    wide['positive_all_periods']=np.logical_and.reduce([wide['expectancy_R_'+p]>0 for p in periods])
    wide['twenty_every_month']=np.logical_and.reduce([wide['min_month_'+p]>=20 for p in periods])
    wide['forty_every_month']=np.logical_and.reduce([wide['min_month_'+p]>=40 for p in periods])
    wide.to_csv(ROOT/'regime_stability.csv')
    lines=['# 全環境の比較表','',
        '主SL（STAGE）、RR1。勝率は打切りを含む確定結果のR>0率。MFE/MAEは固定60分の平均R。',
        '実行数は「1ポジション・約定から15分・親波1回」。無条件採用と、その環境だけを仮に選ぶ場合を区別する。',
        '候補は各段階の初回のみ。月別ゼロ件も最小件数に含む。各段階は独立した比較で、合算しない。','']
    def number(v):return f'{v:.3f}' if pd.notna(v) else '—'
    for stage in ['CHOCH','HL','READY']:
        for period in periods:
            lines += [f'## {stage} / {period}','',
              '| H1 / M15 | N | 勝率 | 平均R [95%区間] | MFE / MAE | 無条件で採用 | 環境単独の実行数 | 単独の月最少 |',
              '|---|---:|---:|---|---|---:|---:|---:|']
            z=s[(s.stage==stage)&(s.period==period)&(s.stop_basis=='STAGE')]
            for cell in CELLS[:9]:
                a=z[(z.cell==cell)&(z['mode']=='CANDIDATES')].iloc[0]
                b=z[(z.cell==cell)&(z['mode']=='UNFILTERED_ACCEPTED')].iloc[0]
                c=z[(z.cell==cell)&(z['mode']=='CELL_ONLY_CAPACITY')].iloc[0]
                win=f'{a.win_rate:.1%}' if pd.notna(a.win_rate) else '—'
                lines.append(f'| {cell} | {a.n} | {win} | {number(a.expectancy_R)} [{number(a.ci_low_R)}, {number(a.ci_high_R)}] | {number(a.mfe60_R)} / {number(a.mae60_R)} | {b.n} | {c.n} | {c.min_month} |')
            lines.append('')
    (ROOT/'regime_tables.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    # Heatmaps show all cells, never just the apparent winners.
    for stage in ['CHOCH','HL','READY']:
        fig,axes=plt.subplots(1,len(periods),figsize=(5*len(periods),4),squeeze=False)
        for ax,period in zip(axes[0],periods):
            z=s[(s.period==period)&(s.stage==stage)&(s.stop_basis=='STAGE')&(s['mode']=='CANDIDATES')].set_index('cell')
            values=np.array([z.loc[cell,'expectancy_R'] for cell in CELLS[:9]]).reshape(3,3)
            ax.imshow(values,cmap='RdYlGn',vmin=-1,vmax=1)
            for i,j in product(range(3),repeat=2):
                row=z.loc[CELLS[i*3+j]];val=row.expectancy_R
                ax.text(j,i,f'{val:+.2f}R\nn={int(row.n)}' if np.isfinite(val) else 'n=0',ha='center',va='center',fontsize=10)
            ax.set_xticks(range(3),['UP','RANGE','DOWN']);ax.set_yticks(range(3),['UP','RANGE','DOWN'])
            ax.set_xlabel('M15 (direct parent)');ax.set_ylabel('H1 (background)');ax.set_title(period)
        fig.suptitle(stage+' | fixed RR 1, stage stop | exploratory means');fig.tight_layout()
        fig.savefig(ROOT/('regime_'+stage.lower()+'.png'),dpi=160);plt.close(fig)
    counts=pd.DataFrame(monthly)
    fig,axes=plt.subplots(3,1,figsize=(11,9),sharex=True)
    months=[m for p in periods for m in PERIODS[p]]
    for ax,stage in zip(axes,['CHOCH','HL','READY']):
        z=counts[(counts.cell=='ALL')&(counts.stage==stage)&(counts.stop_basis=='STAGE')]
        for mode,label,offset,color in [('CANDIDATES','Candidates',-.18,'#7899bc'),('UNFILTERED_ACCEPTED','Executable shadow entries',.18,'#285e3b')]:
            v=z[z['mode']==mode].set_index('month').reindex(months).n
            ax.bar(np.arange(len(months))+offset,v,width=.36,label=label,color=color)
        ax.axhline(20,color='#9c421b',ls='--',lw=1);ax.axhline(40,color='#777777',ls=':',lw=1)
        ax.set_ylabel(stage+' count');ax.set_ylim(bottom=0);ax.legend(loc='upper right',fontsize=8)
    axes[-1].set_xticks(range(len(months)),months,rotation=30)
    fig.suptitle('One position, 15 minutes from fill, one fill per M5 parent | no context filter')
    fig.tight_layout();fig.savefig(ROOT/'monthly_capacity.png',dpi=160);plt.close(fig)
    totals=s[(s.cell=='ALL')&(s.stop_basis=='STAGE')]
    print(totals[['period','stage','mode','n','min_month','mean_month','expectancy_R']].to_string(index=False))
    print('Wrote complete regime, capacity, context and monthly tables.')
if __name__=='__main__':main()
