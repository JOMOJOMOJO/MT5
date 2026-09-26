"""Fixed resistance-distance comparisons. Reuses immutable outcome and occupancy rules."""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import analyze_three_wave_context as prior

R=Path(__file__).resolve().parents[2]
O=R/'reports/qa/three_wave/resistance_research'
THRESHOLDS=[.5,1.,1.2,1.5,2.]
DISTANCES=['res_wave1_active_room_R','res_m5_above_wave1_room_R','res_m15_room_R','res_h1_room_R','res_round_room_R','res_first_room_R']

def main():
    assert json.loads((O/'feature_audit.json').read_text())['passed']
    full=pd.concat([prior.load(p) for p in prior.PERIODS],ignore_index=True)
    features=pd.read_csv(O/'resistance_features.csv')
    features=features.rename(columns={c:'res_'+c for c in features if c not in ['period','id','stop_basis']})
    full=full.merge(features,on=['period','id','stop_basis'],validate='one_to_one').copy()
    for a,b in [('res_known_entry','entry'),('res_known_sl','sl'),('res_known_risk','risk')]:
        assert np.allclose(full[a],full[b],atol=1e-9,rtol=0),(a,b)
    full['res_wave1_active_room_R']=full.res_wave1_room_R.where(full.res_wave1_active)
    expected=full[DISTANCES[:-1]].min(axis=1)
    assert np.allclose(full.res_first_room_R,expected,atol=1e-8,rtol=0),'first resistance mismatch'
    full.to_csv(O/'candidates_with_resistance.csv',index=False)
    primary=full[full.primary].copy()
    primary[primary.stop_basis=='STAGE'].to_csv(O/'primary_candidates_stage.csv',index=False)
    assert len(primary[primary.stop_basis=='STAGE'])==769
    old_ledger=pd.read_csv(prior.ROOT/'execution_ledger.csv')
    stats=[];monthly=[];ledgers=[];distributions=[];baseline_matches=[]
    for (period,stage,basis),d in primary.groupby(['period','stage','stop_basis']):
        tags=dict(period=period,stage=stage,stop_basis=basis)
        base=prior.replay(d);accepted=d[d.id.isin(base[base.accepted].id)]
        old=old_ledger[(old_ledger.period==period)&(old_ledger.stage==stage)&(old_ledger.stop_basis==basis)&(old_ledger.replay=='UNFILTERED')]
        assert base.sort_values('id').reset_index(drop=True).equals(old[['id','reason','accepted']].sort_values('id').reset_index(drop=True))
        baseline_matches.append(tags)
        def record(part,feature,comparison,label,threshold=np.nan,keep_ledger=False):
            trace=prior.replay(part);chosen=part[part.id.isin(trace[trace.accepted].id)]
            unfiltered=accepted[accepted.id.isin(part.id)]
            for mode,z in [('CANDIDATES',part),('UNFILTERED_ACCEPTED',unfiltered),('CONDITION_REPLAY',chosen)]:
                info=tags|dict(feature=feature,comparison=comparison,label=label,threshold_R=threshold,mode=mode)
                stats.append(info|prior.metrics(z,period))
                for month in prior.PERIODS[period]:
                    m=z[z.month==month];closed=m[m.closed]
                    monthly.append(info|dict(month=month,n=len(m),parents=m.parent.nunique(),expectancy_R=closed.result_R.mean(),win_rate=(closed.result_R>0).mean()))
            if keep_ledger:
                t=d[['id','signal_time']].merge(trace,on='id',how='left',validate='one_to_one')
                t['reason']=t.reason.fillna('CONDITION_NOT_MET_OR_MISSING')
                t['accepted']=t.accepted.eq(True)
                ledgers.append(t.assign(**tags,feature=feature,label=label))
        record(d,'ALL','ALL','ALL',keep_ledger=True)
        for field in DISTANCES:
            v=d[field]
            for threshold in THRESHOLDS:
                record(d[v>=threshold-1e-10],field,'GE','GE_'+str(threshold),threshold,True)
            b=pd.cut(v,[-np.inf,0,.5,1,1.2,1.5,2,np.inf],right=False,labels=['NEGATIVE','0_TO_0.5','0.5_TO_1','1_TO_1.2','1.2_TO_1.5','1.5_TO_2','GE_2'])
            for label in ['NEGATIVE','0_TO_0.5','0.5_TO_1','1_TO_1.2','1.2_TO_1.5','1.5_TO_2','GE_2','MISSING']:
                part=d[v.isna()] if label=='MISSING' else d[b==label]
                record(part,field,'BIN',label)
            distributions.append(tags|dict(feature=field,n=v.notna().sum(),missing=v.isna().sum(),mean=v.mean(),min=v.min(),q25=v.quantile(.25),median=v.median(),q75=v.quantile(.75),max=v.max()))
        for kind in ['resistance_count','cluster_count']:
            for bound in ['1p0','1p2','1p5','2p0']:
                field='res_'+kind+'_'+bound;v=d[field]
                for label,mask in [('0',v==0),('1',v==1),('GE_2',v>=2)]:record(d[mask],field,'COUNT',label)
                distributions.append(tags|dict(feature=field,n=v.notna().sum(),missing=v.isna().sum(),mean=v.mean(),min=v.min(),q25=v.quantile(.25),median=v.median(),q75=v.quantile(.75),max=v.max()))
    s=pd.DataFrame(stats);s.to_csv(O/'resistance_statistics.csv',index=False)
    pd.DataFrame(monthly).to_csv(O/'monthly_execution_counts.csv',index=False)
    pd.concat(ledgers,ignore_index=True).to_csv(O/'execution_ledger.csv',index=False)
    pd.DataFrame(distributions).to_csv(O/'feature_distributions.csv',index=False)
    ge=s[s.comparison.isin(['GE','ALL'])]
    keys=['stage','stop_basis','feature','comparison','label','mode'];wide=None
    for period in prior.PERIODS:
        part=ge[ge.period==period].drop(columns=['period','threshold_R']).set_index(keys).add_suffix('_'+period)
        wide=part if wide is None else wide.join(part,how='outer')
    wide['positive_all']=np.logical_and.reduce([wide['expectancy_R_'+p]>0 for p in prior.PERIODS])
    wide['twenty_every_month']=np.logical_and.reduce([wide['min_month_'+p]>=20 for p in prior.PERIODS])
    wide['forty_every_month']=np.logical_and.reduce([wide['min_month_'+p]>=40 for p in prior.PERIODS])
    wide.to_csv(O/'threshold_stability.csv')
    # Human-readable primary hypothesis, including both SL definitions and all entry stages.
    text=['# 最初の抵抗までの距離：固定閾値の全結果','',
          '候補を距離だけで絞る仮想比較。本番フィルターではない。RR1固定。実行制約は1ポジション・約定から15分・親波1回。',
          'MFE/MAEは固定60分の平均R。勝率は打切りを含むR>0率。0件の月も最少件数へ算入。','']
    for basis in ['STAGE','REVERSAL_CONTROL']:
        for stage in ['CHOCH','HL','READY']:
            text += [f'## {stage} / {basis}','',
                '| 期間 | 距離条件 | 候補数 | 候補の勝率 | 候補平均R | MFE / MAE | 実行数 | 月最少〜最多 | 実行平均R |',
                '|---|---|---:|---:|---:|---|---:|---|---:|']
            for period in prior.PERIODS:
                z=s[(s.period==period)&(s.stage==stage)&(s.stop_basis==basis)]
                for threshold in [None]+THRESHOLDS:
                    q=z[z.feature=='ALL'] if threshold is None else z[(z.feature=='res_first_room_R')&(z.comparison=='GE')&(z.threshold_R==threshold)]
                    a=q[q['mode']=='CANDIDATES'].iloc[0];e=q[q['mode']=='CONDITION_REPLAY'].iloc[0]
                    label='無条件' if threshold is None else f'>={threshold:g}R'
                    text.append(f'| {period} | {label} | {a.n} | {a.win_rate:.1%} | {a.expectancy_R:+.3f} | {a.mfe60_R:.3f} / {a.mae60_R:.3f} | {e.n} | {e.min_month}〜{e.max_month} | {e.expectancy_R:+.3f} |')
            text.append('')
    (O/'threshold_tables.md').write_text('\n'.join(text)+'\n',encoding='utf-8')
    fig,axes=plt.subplots(2,3,figsize=(14,8))
    for j,stage in enumerate(['CHOCH','HL','READY']):
        for period,color in zip(prior.PERIODS,['#355c9c','#d47b27','#478150']):
            q=s[(s.stage==stage)&(s.stop_basis=='STAGE')&(s.period==period)&(s.feature=='res_first_room_R')&(s.comparison=='GE')&(s['mode']=='CONDITION_REPLAY')].sort_values('threshold_R')
            axes[0,j].plot(q.threshold_R,q.expectancy_R,'o-',label=period,color=color)
            axes[1,j].plot(q.threshold_R,q.min_month,'o-',label=period,color=color)
        axes[0,j].set_title(stage);axes[0,j].axhline(0,c='gray',ls='--');axes[1,j].axhline(20,c='gray',ls='--')
        axes[0,j].set_ylabel('Executable shadow mean R');axes[1,j].set_ylabel('Minimum monthly entries')
        axes[1,j].set_xlabel('Minimum room to first resistance (R)');axes[0,j].legend(fontsize=8)
    fig.suptitle('Fixed thresholds | RR 1 and stage stop | no threshold selection');fig.tight_layout();fig.savefig(O/'room_expectancy_frequency.png',dpi=160);plt.close(fig)
    audit={'passed':True,'primary_candidates':int((primary.stop_basis=='STAGE').sum()),'all_rows':len(full),'geometry_matches_original':True,'baseline_replays_identical':len(baseline_matches),
           'positive_and_twenty_conditions':int((wide.positive_all & wide.twenty_every_month).sum())}
    (O/'analysis_audit.json').write_text(json.dumps(audit,indent=2))
    print(json.dumps(audit))
    print(s[(s.stage=='CHOCH')&(s.stop_basis=='STAGE')&(s.feature=='res_first_room_R')&(s.comparison=='GE')&(s['mode']=='CONDITION_REPLAY')][['period','threshold_R','n','min_month','expectancy_R']].to_string(index=False))
if __name__=='__main__':main()
