"""Native tick shadow outcomes: causal audits, independent RR capacity, phase tables."""
from pathlib import Path
import argparse,json,hashlib,re
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as md

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/three_wave/m15_phase_research'
PHASES=['DOWN','WAVE1_UP','WAVE2_PULLBACK','WAVE3_UP','RANGE_UNKNOWN']
def read(run):
    p=BASE/run
    c=pd.read_csv(p/'MP_candidates.csv');o=pd.read_csv(p/'MP_outcomes.csv')
    ph=pd.read_csv(p/'MP_phases.csv');res=pd.read_csv(p/'MP_resistance.csv')
    assert c.id.is_unique and not o.duplicated(['id','rr']).any()
    assert set(o.id)<=set(c.id) and o.groupby('id').size().eq(4).all()
    assert (c.phase_asof*1000<=c.entry_msc).all()
    assert (c.signal_time*1000<=c.entry_msc).all()
    assert ph['asof'].is_monotonic_increasing and ph['asof'].is_unique
    for frame in [ph,c.rename(columns={x:x.removeprefix('phase_') for x in c if x.startswith('phase_')})]:
        for point in ['p0','p1','p2']:
            have=frame[point+'_bar']>0
            assert (frame.loc[have,point+'_confirmed']<=frame.loc[have,'asof']).all()
        have=frame.p1_bar>0
        assert (frame.loc[have,'p1_bar']>frame.loc[have,'choch']).all()
        have=frame.p2_bar>0
        assert (frame.loc[have,'p2_bar']>frame.loc[have,'p1_bar']).all()
    expected=pd.merge_asof(c.sort_values('phase_asof')[['id','phase_asof','phase']],ph[['asof','phase']].sort_values('asof'),left_on='phase_asof',right_on='asof')
    assert expected.phase_x.eq(expected.phase_y).all()
    found=res.status.eq('FOUND')
    assert (res.loc[found,'confirmed']*1000<=res.loc[found,'asof_msc']).all()
    for _,g in o.groupby('id'):
        assert g.entry.nunique()==g.sl.nunique()==g.entry_msc.nunique()==1
        ordered=g.sort_values('rr')
        assert ordered.tp.is_monotonic_increasing
        for _,trade in ordered[ordered.outcome=='TP'].iterrows():
            assert ordered[ordered.rr<trade.rr].outcome.eq('TP').all()
    c['entry_time']=pd.to_datetime(c.entry_msc,unit='ms');c['month']=c.entry_time.dt.strftime('%Y-%m')
    d=o.merge(c[['id','parent','attempt','entry_time','month']],on='id',validate='many_to_one')
    d['path_complete']=d.path_complete.astype(str).str.lower().isin(['true','1'])
    d['complete']=d.outcome.isin(['SL','TP'])
    # Daily journal warnings are a conservative quality tag, not a trading filter.
    journal=(p/'tester.log').read_text(encoding='utf-8-sig')
    dates=sorted(set(re.findall(r'(\d{4}\.\d{2}\.\d{2}) 23:59 - .*real ticks (?:absent|discarded)',journal)))
    bad_days=[pd.Timestamp(day).timestamp()*1000 for day in dates]
    c['entry_on_tick_warning_day']=[any(t<=x<t+86400000 for t in bad_days) for x in c.entry_msc]
    d['path_overlaps_tick_warning_day']=[any(start<t+86400000 and max(end,last)>=t for t in bad_days)
        for start,end,last in zip(d.entry_msc,d.exit_msc,d.path_last_msc)]
    quality=dict(warning_days=dates,candidates_on_warning_days=int(c.entry_on_tick_warning_day.sum()),
                 candidates_with_any_path_overlap=int(d[d.path_overlaps_tick_warning_day].id.nunique()),
                 limitation='Daily tags cannot certify unaffected feature history; no rows excluded from primary statistics.')
    (p/'tick_quality.json').write_text(json.dumps(quality,indent=2))
    audit=dict(run=run,candidates=len(c),outcomes=len(o),phase_bars=len(ph),causal_assertions='PASS',
               phase_counts=c.phase.value_counts().to_dict(),censored=int((~d.complete).sum()),invalid=c.status.value_counts().to_dict())
    (p/'audit.json').write_text(json.dumps(audit,indent=2))
    return c,d,ph,res
def stat(g):
    done=g[g.complete];r=done.result_r
    path=g[g.path_complete]
    out=dict(count=len(g),closed=len(done),censored=len(g)-len(done),win_rate=(r>0).mean(),expectancy_r=r.mean(),
             pf=r[r>0].sum()/-r[r<0].sum() if (r<0).any() else np.nan,
             mean_mfe_exit=g.mfe_to_exit.mean(),mean_mae_exit=g.mae_to_exit.mean(),
             path_n=len(path),mean_mfe_24h=path.mfe_until_sl_or_24h.mean(),median_mfe_24h=path.mfe_until_sl_or_24h.median(),
             mean_mae_24h=path.mae_until_sl_or_24h.mean())
    for quantile in [.25,.75,.9]:out[f'mfe_q{int(quantile*100)}']=path.mfe_until_sl_or_24h.quantile(quantile)
    if len(r)>1:
        rng=np.random.default_rng(270926)
        means=r.to_numpy()[rng.integers(0,len(r),size=(5000,len(r)))].mean(axis=1)
        out['mean_r_iid_ci_low'],out['mean_r_iid_ci_high']=np.quantile(means,[.025,.975])
    for rr in [1.,1.2,1.5,2.]:out[f'reach_{rr}r']=(path.mfe_until_sl_or_24h>=rr-1e-9).mean()
    return out
def ledger(d,phase_filter=None):
    out=[]
    for rr,g in d.groupby('rr'):
        busy=0;fill=-1e18;used=set()
        for _,r in g.sort_values(['entry_msc','parent','id'],ascending=[True,False,True]).iterrows():
            why='ACCEPT'
            if phase_filter and r.phase!=phase_filter:why='OTHER_PHASE'
            elif r.parent in used:why='PARENT_ALREADY_USED'
            elif r.entry_msc<busy:why='POSITION_OPEN'
            elif r.entry_msc<fill+900000:why='COOLDOWN'
            if why=='ACCEPT':
                fill=r.entry_msc;used.add(r.parent);busy=r.exit_msc if r.complete else float('inf')
            out.append(dict(id=r.id,rr=rr,phase_filter=phase_filter or 'ALL',decision=why))
    return pd.DataFrame(out)
def analyze(runs):
    output=BASE/'analysis';output.mkdir(exist_ok=True)
    stats=[];monthly=[];ledgers=[];all_c=[];all_d=[];resall=[]
    for run in runs:
        c,d,ph,res=read(run);c['run']=run;d['run']=run;res['run']=run
        all_c.append(c);all_d.append(d);resall.append(res)
        cfg=(BASE/run/'test.ini').read_text()
        dates={l.split('=')[0]:l.split('=')[1] for l in cfg.splitlines() if l.startswith(('FromDate=','ToDate='))}
        months=pd.period_range(pd.Timestamp(dates['FromDate']),pd.Timestamp(dates['ToDate'])-pd.Timedelta(days=1),freq='M').astype(str)
        for filter_phase in [None]+PHASES:
            le=ledger(d,filter_phase);le['run']=run;ledgers.append(le)
            joined=d.merge(le[['id','rr','decision']],on=['id','rr'])
            for rr in [1.,1.2,1.5,2.]:
                if filter_phase is None:
                    for scope,frame in [('CANDIDATES',joined),('UNFILTERED_ACCEPTED',joined[joined.decision=='ACCEPT'])]:
                        for state in PHASES+['ALL']:
                            q=frame[frame.rr==rr];q=q if state=='ALL' else q[q.phase==state]
                            stats.append(dict(run=run,scope=scope,rr=rr,phase=state,**stat(q)))
                for month in months:
                    q=joined[(joined.rr==rr)&(joined.month==month)]
                    for state in ([filter_phase] if filter_phase else PHASES+['ALL']):
                        v=q if state=='ALL' else q[q.phase==state]
                        monthly.append(dict(run=run,rr=rr,scope='PHASE_ONLY_CAPACITY' if filter_phase else 'UNFILTERED',phase=state,month=month,candidates=len(v),accepted=int(v.decision.eq('ACCEPT').sum())))
    cs=pd.concat(all_c);ds=pd.concat(all_d);rs=pd.concat(resall)
    cs.to_csv(output/'candidates_with_phase.csv',index=False)
    ds.to_csv(output/'all_rr_outcomes.csv',index=False)
    rs.to_csv(output/'resistance_features.csv',index=False)
    pd.DataFrame(stats).to_csv(output/'phase_statistics.csv',index=False)
    pd.DataFrame(monthly).to_csv(output/'monthly_capacity.csv',index=False)
    pd.concat(ledgers).to_csv(output/'execution_ledger.csv',index=False)
    # Matched candidate RR difference; never substitute absent/censored outcomes with zero.
    pairs=[]
    for (run,state),g in ds.groupby(['run','phase']):
        p=g[g.complete].pivot(index='id',columns='rr',values='result_r')
        for rr in [1.2,1.5,2.]:
            if 1.0 not in p or rr not in p:continue
            a=p[[1.0,rr]].dropna();delta=a[rr]-a[1.0]
            pairs.append(dict(run=run,phase=state,rr=rr,paired=len(a),mean_delta_vs_rr1=delta.mean(),
                              rr1_win_larger_loss=int(((a[1.0]>0)&(a[rr]<0)).sum()),rr1_win_larger_win=int(((a[1.0]>0)&(a[rr]>0)).sum())))
    pd.DataFrame(pairs).to_csv(output/'paired_rr_comparison.csv',index=False)
    # Fixed diagnostic boundary only; missing resistance stays separate.
    resistance_stats=[]
    for (run,tf,kind),r in rs.groupby(['run','tf','kind']):
        z=ds[ds.run==run].merge(r[['id','status','distance_r']],on='id',validate='many_to_one')
        z['room_group']=np.where(z.status!='FOUND','MISSING',np.where(z.distance_r>=1.2,'GE_1.2R','LT_1.2R'))
        for (rr,state,group),g in z.groupby(['rr','phase','room_group']):
            resistance_stats.append(dict(run=run,tf=tf,kind=kind,rr=rr,phase=state,room_group=group,**stat(g)))
    pd.DataFrame(resistance_stats).to_csv(output/'resistance_diagnostics.csv',index=False)
    table=pd.DataFrame(stats)
    fig,axes=plt.subplots(1,len(runs),figsize=(max(7,6*len(runs)),4),squeeze=False,layout='constrained')
    for ax,run in zip(axes[0],runs):
        t=table[(table.run==run)&(table.scope=='CANDIDATES')&(table.phase!='ALL')]
        mat=t.pivot(index='phase',columns='rr',values='expectancy_r').reindex(PHASES)
        im=ax.imshow(mat.to_numpy(),cmap='RdYlGn',vmin=-1,vmax=1.5,aspect='auto')
        ax.set_xticks(range(4),['1R','1.2R','1.5R','2R']);ax.set_yticks(range(5),PHASES);ax.set_title(run)
        for i,state in enumerate(PHASES):
            for j,rr in enumerate([1.,1.2,1.5,2.]):
                row=t[(t.phase==state)&(t.rr==rr)].iloc[0];v=row.expectancy_r
                ax.text(j,i,f'{v:+.2f}\nn={int(row.closed)}' if pd.notna(v) else 'no sample',ha='center',va='center',fontsize=9)
    fig.colorbar(im,ax=list(axes[0]),label='Mean price R (spread included; other costs excluded)')
    fig.savefig(output/'phase_rr_expectancy.png',dpi=140);plt.close(fig)
    fig,ax=plt.subplots(figsize=(11,4),layout='constrained');m=pd.DataFrame(monthly)
    for rr in [1.,1.2,1.5,2.]:
        q=m[(m.rr==rr)&(m.scope=='UNFILTERED')&(m.phase=='ALL')].sort_values('month')
        ax.plot(q.month,q.accepted,marker='o',label=f'{rr}R')
    ax.axhline(20,color='red',ls='--',label='20 / month');ax.set(title='Executable opportunities: one position, 15-minute cooldown, one per parent',ylabel='Count');ax.legend(ncol=5)
    fig.savefig(output/'monthly_execution.png',dpi=140);plt.close(fig)
    print(pd.DataFrame(stats).query("scope=='CANDIDATES' and rr==1.2")[['run','phase','count','win_rate','expectancy_r','pf','reach_1.0r','reach_2.0r']].to_string(index=False))
def charts(run):
    c,d,ph,res=read(run);p=BASE/run
    m1=pd.read_csv(p/'MP_m1.csv');m1['dt']=pd.to_datetime(m1.time,unit='s')
    count=0
    for name in PHASES:
        subset=c[c.phase==name]
        if subset.empty:continue
        row=subset.iloc[0];end=row.entry_time+pd.Timedelta(hours=2);start=row.entry_time-pd.Timedelta(hours=10)
        h=ph[(ph.bar>=start.timestamp())&(ph.bar<=end.timestamp())].copy();h['dt']=pd.to_datetime(h.bar,unit='s')
        fig,ax=plt.subplots(2,1,figsize=(12,7),layout='constrained')
        ax[0].vlines(h.dt,h.low,h.high,color='gray',linewidth=.8);ax[0].plot(h.dt,h.close,linewidth=.7,color='gray')
        for point,col in [('p0','blue'),('p1','green'),('p2','orange')]:
            if row['phase_'+point+'_bar']>0:
                t=pd.Timestamp(row['phase_'+point+'_bar'],unit='s');known=pd.Timestamp(row['phase_'+point+'_confirmed'],unit='s');price=row['phase_'+point]
                ax[0].scatter([t],[price],color=col,label=point+' pivot');ax[0].scatter([known],[price],color=col,marker='x',label=point+' confirmed')
        for state,col in zip(PHASES,['salmon','yellowgreen','gold','limegreen','lightgray']):
            for _,bar in h[h.phase==state].iterrows():
                begin=pd.Timestamp(bar['asof'],unit='s');ax[0].axvspan(begin,begin+pd.Timedelta(minutes=15),alpha=.15,color=col)
        ax[0].axvline(row.entry_time,color='black',linestyle='--');ax[0].set_title(f'{name}: M15 state known at entry; colored intervals start at bar CLOSE')
        if ax[0].get_legend_handles_labels()[0]:ax[0].legend(fontsize=8,ncol=3)
        l=m1[(m1.dt>=row.entry_time-pd.Timedelta(minutes=90))&(m1.dt<=end)]
        ax[1].vlines(l.dt,l.low,l.high,color='gray',linewidth=.6);ax[1].plot(l.dt,l.close,color='gray',linewidth=.6)
        ax[1].scatter([row.entry_time],[row.entry],marker='^',color='blue',label='entry Ask')
        ax[1].axhline(row.sl,color='red',label='fixed SL')
        for rr in [1.,1.2,1.5,2.]:ax[1].axhline(row.entry+rr*row.risk,linestyle=':',label=f'{rr}R')
        ax[1].legend(fontsize=8,ncol=6);ax[1].set_title('M1 candidate unchanged; diagnostic reconstruction, not an MT5 screenshot')
        for a in ax:a.xaxis.set_major_formatter(md.DateFormatter('%m-%d %H:%M'))
        fig.savefig(p/f'qa_{name}.png',dpi=130);plt.close(fig);count+=1
    print('QA charts',count)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('runs',nargs='+');p.add_argument('--charts',action='store_true');a=p.parse_args()
    if a.charts:
        for run in a.runs:charts(run)
    else:analyze(a.runs)
