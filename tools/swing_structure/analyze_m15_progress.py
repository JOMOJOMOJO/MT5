"""Causal M15 progress annotation of frozen native candidates; no order execution."""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
from analyze_m15_phase_research import stat

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/three_wave/m15_phase_research'
OUT=ROOT/'reports/qa/three_wave/m15_progress_research'
RUNS=['known_close_2025h1','holdout_close_2024q3']
STATES=['DOWN_CONTINUING','DOWN_WEAKENING','W1_ACTIVE','W2_PULLBACK_ACTIVE','W3_CANDIDATE','W3_CONFIRMED','UNKNOWN']

def pivots(a,i):
    k=i-2
    if k<2:return []
    out=[]
    for side in [0,1]:
        x=a[k,side];left=a[k-2:k,side];right=a[k+1:i+1,side]
        yes=(x>left).all() and (x>=right).all() if side==0 else (x<left).all() and (x<=right).all()
        if yes:out.append((side,x,k))
    return out

def replay(b):
    """All updates occur at a closed M15 bar. No candidate or outcome is consulted."""
    a=b[['high','low','close']].to_numpy();ts=b.bar.to_numpy();asof=b['asof'].to_numpy()
    hs=[];ls=[];legacy_h=[];legacy_l=[];state='UNKNOWN';h0=p0=None
    used_h0=-1;weak_low=np.nan;weak_since=0;runhigh=np.nan;top=np.nan;pull=0;break_time=0;w3=0;protect=None
    ema=np.nan;atr=np.nan;trs=[];rows=[]
    reset_reasons={'ORIGIN_OR_CONFIRMED_HL_BROKEN','WAVE3_FIRST_HIGH_CONFIRMED','P1_BREAK_WITHOUT_CONFIRMED_P2'}
    for i,(high,low,close) in enumerate(a):
        now=asof[i];prev=a[i-1,2] if i else close
        ema=close if i==0 else ema+2/21*(close-ema)
        tr=max(high-low,abs(high-prev),abs(low-prev));trs.append(tr)
        if i==13:atr=np.mean(trs)
        elif i>13:atr=(atr*13+tr)/14
        events=pivots(a,i)
        # Reconstruct exact old DOWN reference levels using native reset reasons.
        if b.reason.iloc[i]!='ORIGIN_OR_CONFIRMED_HL_BROKEN':
            for side,price,k in events:
                target=legacy_h if side==0 else legacy_l
                target.append((price,int(ts[k]),int(now)));del target[:-3]
        if b.reason.iloc[i] in reset_reasons:legacy_h=[];legacy_l=[]
        for side,price,k in events:
            target=hs if side==0 else ls
            target.append((price,int(ts[k]),int(now)));del target[:-3]
        down=len(hs)>=2 and len(ls)>=2 and hs[-1][0]<hs[-2][0] and ls[-1][0]<ls[-2][0]
        reason='HOLD';active=state in ['W1_ACTIVE','W2_PULLBACK_ACTIVE','W3_CONFIRMED']
        invalid=active and (close<p0[0] or (protect is not None and close<protect[0]))
        if invalid:
            state='UNKNOWN';reason='ORIGIN_OR_PROTECTED_LOW_CLOSE_BREAK';h0=p0=None
            top=runhigh=np.nan;pull=break_time=w3=0;protect=None;weak_since=0;weak_low=np.nan
        elif active:
            if state=='W1_ACTIVE':
                if now>break_time and close<prev and close<=runhigh:
                    top=runhigh;pull=int(now);state='W2_PULLBACK_ACTIVE';reason='FIRST_LOWER_CLOSE'
                else:runhigh=max(runhigh,high)
            elif state=='W2_PULLBACK_ACTIVE' and now>pull and close>top:
                state='W3_CONFIRMED';w3=int(now);reason='FIXED_RUNNING_HIGH_CLOSE_BREAK'
            elif state=='W3_CONFIRMED':
                for side,price,k in events:
                    if side==1 and ts[k]>=w3 and price>p0[0] and (protect is None or price>protect[0]):
                        protect=(price,int(ts[k]),int(now));reason='PROTECTED_LOW_CONFIRMED'
        else:
            if down and close>hs[-1][0] and close>=ls[-1][0] and hs[-1][1]!=used_h0:
                h0=hs[-1];p0=ls[-1];used_h0=h0[1];break_time=int(now)
                runhigh=high;top=np.nan;pull=w3=0;protect=None;weak_since=0;weak_low=np.nan
                state='W1_ACTIVE';reason='H0_CLOSE_BREAK'
            elif down and close<=hs[-1][0]:
                if weak_since and close<weak_low:weak_since=0;weak_low=np.nan
                if i and close>a[i-1,0]:
                    if not weak_since:weak_since=int(now);weak_low=min(low,a[i-1,1])
                    reason='PREVIOUS_BAR_HIGH_CLOSE_BREAK'
                state='DOWN_WEAKENING' if weak_since else 'DOWN_CONTINUING'
            else:state='UNKNOWN';weak_since=0;weak_low=np.nan
        slope=ema-rows[-1]['ema20'] if rows else np.nan
        speed=(close-a[i-3,2])/3/atr if i>=3 and atr>0 else np.nan
        speed_price=(close-a[i-3,2])/45 if i>=3 else np.nan
        row=dict(asof=int(now),base_state=state,reason=reason,ema20=ema,ema20_slope_price=slope,
                 atr14=atr,ema20_slope_atr=slope/atr if atr>0 else np.nan,
                 close_velocity_atr_per_bar=speed,down_speed_atr_per_bar=-speed,
                 close_velocity_price_per_minute=speed_price,weak_since=weak_since,weak_low=weak_low,
                 m15_break_asof=break_time,pullback_asof=pull,fixed_wave1_high=top,w3_asof=w3,
                 latest_low_change=ls[-1][0]-ls[-2][0] if len(ls)>1 else np.nan,
                 preceding_low_change=ls[-2][0]-ls[-3][0] if len(ls)>2 else np.nan)
        for name,p in [('active_h0',h0),('active_p0',p0),('latest_low',ls[-1] if ls else None),
                       ('legacy_h0',legacy_h[-1] if legacy_h else None),('legacy_low',legacy_l[-1] if legacy_l else None)]:
            row[name]=p[0] if p else np.nan;row[name+'_bar']=p[1] if p else 0;row[name+'_confirmed']=p[2] if p else 0
        row['legacy_low_change']=legacy_l[-1][0]-legacy_l[-2][0] if len(legacy_l)>1 else np.nan
        row['legacy_preceding_low_change']=legacy_l[-2][0]-legacy_l[-3][0] if len(legacy_l)>2 else np.nan
        rows.append(row)
    return pd.DataFrame(rows)

def annotate(c,r):
    c=c.copy().rename(columns={'phase':'old_phase'})
    c['entry_sec']=c.entry_msc/1000
    x=pd.merge_asof(c.sort_values('entry_sec'),r.assign(asof=r['asof'].astype(float)),left_on='entry_sec',right_on='asof')
    x['m5_reversal_confirmed_asof']=x.parent+300
    x['m1_choch_confirmed_asof']=x.attempt+60
    x['m5_already_upturned']=(x.m5_reversal_confirmed_asof<=x.entry_sec)&(x.m5_p1_confirmed<=x.entry_sec)&(x.bid>=x.m5_p0)
    x['m1_turn_after_pullback']=(x.m1_choch_confirmed_asof>=x.pullback_asof)&(x.m1_choch_confirmed_asof<=x.entry_sec)&(x.pullback_asof>0)
    x['state']=x.base_state
    candidate=(x.base_state=='W2_PULLBACK_ACTIVE')&x.m5_already_upturned&x.m1_turn_after_pullback
    x.loc[candidate,'state']='W3_CANDIDATE'
    for name in ['m15_break_asof','pullback_asof','w3_asof','weak_since']:
        x[name+'_age_minutes']=np.where(x[name]>0,(x.entry_sec-x[name])/60,np.nan)
    x['h0_distance_r']=(x.legacy_h0-x.entry)/x.risk
    return x

def future_labels(x,b):
    """Post-entry labels, never fed to replay/annotate."""
    rows=[]
    for _,r in x.iterrows():
        future=b[(b['asof']>r.entry_sec)&(b.close>r.legacy_h0)]
        first=float(future.iloc[0]['asof']) if len(future) and pd.notna(r.legacy_h0) else np.nan
        elapsed=(first-r.entry_sec)/60
        available=(b['asof'].iloc[-1]-r.entry_sec)/60
        row=dict(id=r.id,h0_first_break_asof=first,h0_break_minutes=elapsed,h0_observed_minutes=available,
                 h0_ever_broken_in_remaining_data=pd.notna(first))
        for minutes in [30,60,120]:
            row[f'h0_close_break_within_{minutes}m']=True if elapsed<=minutes else (False if available>=minutes else pd.NA)
        rows.append(row)
    return pd.DataFrame(rows)

def main():
    OUT.mkdir(exist_ok=True,parents=True);allc=[];alld=[];allold=[];audits=[];hashes={}
    for run in RUNS:
        p=BASE/run
        for f in ['MP_candidates.csv','MP_outcomes.csv','MP_phases.csv','MP_resistance.csv']:
            hashes[str((p/f).relative_to(ROOT))]=hashlib.sha256((p/f).read_bytes()).hexdigest()
        c=pd.read_csv(p/'MP_candidates.csv');b=pd.read_csv(p/'MP_phases.csv');d=pd.read_csv(p/'MP_outcomes.csv')
        r=replay(b);x=annotate(c,r)
        for reason in ['H0_CLOSE_BREAK','FIRST_LOWER_CLOSE','FIXED_RUNNING_HIGH_CLOSE_BREAK']:
            mask=r.reason.eq(reason)
            if reason=='H0_CLOSE_BREAK':assert (b.loc[mask,'close'].to_numpy()>r.loc[mask,'active_h0'].to_numpy()).all()
            if reason=='FIRST_LOWER_CLOSE':
                assert (b.loc[mask,'close'].to_numpy()<b.close.shift(1)[mask].to_numpy()).all()
                assert (r.loc[mask,'pullback_asof']>r.loc[mask,'m15_break_asof']).all()
            if reason=='FIXED_RUNNING_HIGH_CLOSE_BREAK':
                assert (b.loc[mask,'close'].to_numpy()>r.loc[mask,'fixed_wave1_high'].to_numpy()).all()
                assert (r.loc[mask,'w3_asof']>r.loc[mask,'pullback_asof']).all()
        assert x.id.is_unique and len(x)==len(c)
        assert x['asof'].le(x.entry_sec).all()
        for name in ['active_h0','active_p0','latest_low','legacy_h0','legacy_low']:
            assert x[name+'_confirmed'].le(x.entry_sec).all()
        # Prefix replay and future perturbation must preserve entry-time state/features.
        cuts=sorted({len(b)//2,len(b)-50,int(b['asof'].searchsorted(x.entry_sec.iloc[0],side='right'))})
        for cut in cuts:
            pd.testing.assert_frame_equal(replay(b.iloc[:cut]),r.iloc[:cut],check_dtype=False)
        cut=cuts[0];changed=b.copy();changed.loc[cut:,['high','low','close']]*=1.1
        pd.testing.assert_frame_equal(replay(changed).iloc[:cut],r.iloc[:cut],check_dtype=False)
        # Repeat full replay for deterministic equality.
        pd.testing.assert_frame_equal(r,replay(b))
        old=x[x.old_phase=='DOWN'].copy()
        assert old.legacy_h0.notna().all() and (old.legacy_h0>=b.set_index('asof').loc[old['asof'],'close'].to_numpy()).all()
        old=old.merge(future_labels(old,b),on='id',validate='one_to_one')
        old['latest_low_extension_price']=-old.legacy_low_change
        old['latest_low_extension_atr']=-old.legacy_low_change/old.atr14
        old['preceding_low_extension_price']=-old.legacy_preceding_low_change
        old['low_extension_contracted']=np.where(old.legacy_preceding_low_change.notna(),
            old.latest_low_extension_price<old.preceding_low_extension_price,np.nan)
        warnings=json.loads((p/'tick_quality.json').read_text())['warning_days']
        for frame in [x,old]:
            frame['entry_on_tick_warning_day']=pd.to_datetime(frame.entry_msc,unit='ms').dt.strftime('%Y.%m.%d').isin(warnings)
        resist=pd.read_csv(p/'MP_resistance.csv')
        wide=resist.pivot(index='id',columns=['tf','kind'],values='distance_r')
        wide.columns=['resistance_'+a.removeprefix('PERIOD_')+'_'+z+'_r' for a,z in wide.columns]
        x=x.merge(wide,on='id',how='left');old=old.merge(wide,on='id',how='left')
        x['run']=run;old['run']=run;r['run']=run
        x['month']=pd.to_datetime(x.entry_msc,unit='ms').dt.strftime('%Y-%m')
        old['month']=pd.to_datetime(old.entry_msc,unit='ms').dt.strftime('%Y-%m')
        d=d.rename(columns={'phase':'old_phase'}).merge(x[['id','state','month']],on='id',validate='many_to_one')
        d['run']=run;d['complete']=d.outcome.isin(['SL','TP'])
        d['path_complete']=d.path_complete.astype(str).str.lower().isin(['true','1'])
        assert d.groupby('id').size().eq(4).all()
        for col in ['entry','sl','tp','result_r','entry_msc','exit_msc']:
            orig=pd.read_csv(p/'MP_outcomes.csv').set_index(['id','rr'])[col].sort_index()
            pd.testing.assert_series_equal(orig,d.set_index(['id','rr'])[col].sort_index())
        r.to_csv(OUT/(run+'_states.csv'),index=False)
        allc.append(x);alld.append(d);allold.append(old)
        audits.append(dict(run=run,candidates=len(x),old_down=len(old),prefix_cuts=cuts,
            prefix_invariance='PASS',future_perturbation='PASS',deterministic_replay='PASS',
            transition_invariants='PASS',entry_sl_tp_outcome_unchanged='PASS'))
    cs=pd.concat(allc);ds=pd.concat(alld);olds=pd.concat(allold)
    assert len(cs)==119 and len(olds)==28
    cs.to_csv(OUT/'candidates_with_progress.csv',index=False)
    ds.to_csv(OUT/'fixed_rr_outcomes.csv',index=False)
    olds.to_csv(OUT/'previous_down_28_diagnostics.csv',index=False)
    stats=[];months=[];oldstats=[];breakstats=[]
    for run in RUNS:
        for state in STATES+['ALL']:
            for rr in [1.,1.2,1.5,2.]:
                g=ds[(ds.run==run)&(ds.rr==rr)];g=g if state=='ALL' else g[g.state==state]
                stats.append(dict(run=run,state=state,rr=rr,**stat(g)))
                oldids=olds.loc[olds.run==run,'id'];o=g[g.id.isin(oldids)]
                oldstats.append(dict(run=run,state=state,rr=rr,**stat(o)))
            for month in sorted(cs.loc[cs.run==run,'month'].unique()):
                q=cs[(cs.run==run)&(cs.month==month)];q=q if state=='ALL' else q[q.state==state]
                months.append(dict(run=run,month=month,state=state,count=len(q)))
            q=olds[olds.run==run];q=q if state=='ALL' else q[q.state==state]
            row=dict(run=run,state=state,count=len(q),median_h0_distance_r=q.h0_distance_r.median(),
                     median_minutes_among_breaks=q.h0_break_minutes.median(),m5_upturned=int(q.m5_already_upturned.sum()))
            for t in [30,60,120]:
                v=q[f'h0_close_break_within_{t}m'].dropna();row[f'break_{t}m_n']=int(v.sum());row[f'break_{t}m_denominator']=len(v);row[f'break_{t}m_rate']=v.mean() if len(v) else np.nan
            breakstats.append(row)
    pd.DataFrame(stats).to_csv(OUT/'state_statistics.csv',index=False)
    pd.DataFrame(months).to_csv(OUT/'monthly_counts.csv',index=False)
    pd.DataFrame(oldstats).to_csv(OUT/'previous_down_state_statistics.csv',index=False)
    pd.DataFrame(breakstats).to_csv(OUT/'previous_down_break_statistics.csv',index=False)
    feature_rows=[]
    features=['h0_distance_r','latest_low_extension_price','latest_low_extension_atr',
              'ema20_slope_price','ema20_slope_atr','down_speed_atr_per_bar']
    for run,q in olds.groupby('run'):
        for label,g in q.groupby('h0_close_break_within_120m'):
            for feature in features:
                v=g[feature].dropna()
                feature_rows.append(dict(run=run,future_h0_break_120m=label,feature=feature,n=len(v),
                                         mean=v.mean(),median=v.median(),q25=v.quantile(.25),q75=v.quantile(.75)))
    pd.DataFrame(feature_rows).to_csv(OUT/'previous_down_features_by_future_label.csv',index=False)
    cs.groupby(['run','old_phase','state']).size().rename('count').reset_index().to_csv(OUT/'old_vs_new_states.csv',index=False)
    (OUT/'audit.json').write_text(json.dumps(audits,indent=2))
    (OUT/'source_hashes.json').write_text(json.dumps(hashes,indent=2))
    print(pd.DataFrame(stats).query('rr==1.2')[['run','state','count','expectancy_r']].to_string(index=False))
    print(pd.DataFrame(breakstats).query('count>0').to_string(index=False))

if __name__=='__main__':main()
