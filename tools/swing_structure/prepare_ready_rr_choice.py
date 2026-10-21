"""Fixed-entry RR1/RR1.2 labels and causal waveform features; no EA changes."""
from pathlib import Path
import json,hashlib
import numpy as np
import pandas as pd
from tsfresh import extract_features
from tsfresh.feature_extraction import MinimalFCParameters
from analyze_ready_generated_ticks import raw_path
from analyze_ready_failures import atr
from run_ready_deep_review import add_entry_geometry,FEATURES

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'reports/qa/three_wave/ready_generated_tick_ml'
OUT=ROOT/'reports/qa/three_wave/ready_rr_choice'
TFS={'M1':60,'M5':300,'M15':900,'H1':3600}
CHANNELS=[f'{tf}_{kind}' for tf in TFS for kind in ['change','body','range']]
EPS=1e-10

def barrier(b,entry_msc,sl,tp):
    start=int(entry_msc//60000*60)
    q=b[b.time>=start]
    hit=q[(q.low<=sl+EPS)|(q.high>=tp-EPS)]
    if hit.empty:return dict(outcome='END_CENSORED',bar=0,both=False,upper_msc=0)
    r=hit.iloc[0];down=r.low<=sl+EPS;up=r.high>=tp-EPS
    return dict(outcome='AMBIGUOUS' if down and up else ('SL' if down else 'TP'),bar=int(r.time),
                both=bool(down and up),upper_msc=int((r.time+60)*1000))

def calculate_labels(row,b):
    tp1=round((row.entry+row.risk)/row.tick_size)*row.tick_size
    a=barrier(b,row.entry_msc,row.sl,tp1);c=barrier(b,row.entry_msc,row.sl,row.tp)
    # Keep native labels/timing for RR1.2, and verify the minute-level reconstruction.
    if c['outcome'] not in ['AMBIGUOUS','END_CENSORED']:
        assert c['outcome']==row.outcome,(row.signal_id,c,row.outcome)
        assert c['bar']==row.exit_msc//60000*60
    if a['outcome']=='SL':assert row.outcome=='SL'
    out1=a['outcome']
    result1=(tp1-row.entry)/row.risk if out1=='TP' else (row.result_r if out1=='SL' else np.nan)
    exit1=a['upper_msc']
    if out1=='SL':exit1=int(row.exit_msc)
    elif out1=='TP' and row.exit_msc>0 and int(row.exit_msc//60000*60)==a['bar']:
        exit1=min(exit1,int(row.exit_msc))
    exclusions=[]
    if a['both']:exclusions.append('RR1_SAME_MINUTE_SL_TP')
    if c['both']:exclusions.append('RR12_SAME_MINUTE_SL_TP')
    if a['outcome']=='END_CENSORED' or row.outcome=='END_CENSORED':exclusions.append('END_CENSORED')
    eligible=not exclusions
    category=(2 if row.outcome=='TP' else (1 if out1=='TP' else 0)) if eligible else np.nan
    if eligible:assert (out1,row.outcome) in [('TP','TP'),('TP','SL'),('SL','SL')]
    return dict(rr1_tp=tp1,rr1_outcome=out1,rr1_result_r=result1,rr1_exit_msc=exit1,
        rr1_hit_bar=a['bar'],rr1_both=a['both'],rr12_both=c['both'],
        rr12_result_r=row.result_r,rr12_exit_msc=row.exit_msc,
        paired_eligible=eligible,label_exclusion=';'.join(exclusions) if exclusions else 'INCLUDED',
        reach_class=category,label_known_msc=max(exit1,row.exit_msc) if eligible else 0,
        rr1_exit_time_precision='MINUTE_END_CONSERVATIVE' if out1=='TP' else 'NATIVE_SL_TICK')

def extract_sequence(row,frames):
    cut=row.entry_msc/1000;channels=[];audit=[]
    for tf,period in TFS.items():
        b=frames[tf];known=b[(b.time+period<=cut)&(b.available_at<=cut)]
        assert len(known)>=33
        window=known.tail(33);a=float(known.atr14.iloc[-1]);assert np.isfinite(a) and a>0
        channels.extend([np.diff(window.close.to_numpy())/a,
                         (window.close-window.open).to_numpy()[1:]/a,
                         (window.high-window.low).to_numpy()[1:]/a])
        audit.append(dict(signal_id=row.signal_id,tf=tf,entry_msc=row.entry_msc,
            first_bar=int(window.time.iloc[0]),last_bar=int(window.time.iloc[-1]),max_available_at=float(window.available_at.max())))
    seq=np.stack(channels,axis=1);assert seq.shape==(32,12) and np.isfinite(seq).all()
    return seq,audit

def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    x=add_entry_geometry(pd.read_csv(SOURCE/'all_candidates.csv')).sort_values('entry_msc').reset_index(drop=True)
    labels=[];series=[];audits=[];hashes={};qa=[]
    for year,g in x.groupby('year'):
        print('PREPARE',year,flush=True);frames={}
        for tf in TFS:
            path=raw_path(year)/f'TW_ml_bars_PERIOD_{tf}.csv'
            b=pd.read_csv(path);assert b.time.is_unique and b.time.is_monotonic_increasing
            b['atr14']=atr(b,14);frames[tf]=b
            hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
        for row in g.itertuples():
            b=frames['M1'];entrybar=b[b.time==row.entry_msc//60000*60].iloc[0]
            assert abs(entrybar.open-row.bid)<1e-8
            labels.append(calculate_labels(row,b));seq,a=extract_sequence(row,frames);series.append(seq);audits.extend(a)
        # Future mutation invariance for each year; all-window availability is audited below.
        row=next(g.iloc[[len(g)//2]].itertuples());original,_=extract_sequence(row,frames)
        altered={k:v.copy() for k,v in frames.items()}
        for tf,b in altered.items():
            b.loc[(b.time+TFS[tf]>row.entry_msc/1000)|(b.available_at>row.entry_msc/1000),['open','high','low','close']]+=100
            b['atr14']=atr(b,14)
        changed,_=extract_sequence(row,altered);np.testing.assert_allclose(original,changed,rtol=0,atol=1e-12)
        qa.append(dict(year=int(year),future_mutation='PASS'))
    lab=pd.DataFrame(labels);x=x.drop(columns=['label_exclusion']).join(lab)
    sequences=np.stack(series);x.to_csv(OUT/'candidates.csv',index=False)
    np.savez_compressed(OUT/'sequences.npz',values=sequences,signal_ids=x.signal_id.to_numpy(dtype=str))
    pd.DataFrame(audits).to_csv(OUT/'sequence_availability.csv',index=False)
    long=pd.DataFrame(dict(id=np.repeat(np.arange(len(x)),32),step=np.tile(np.arange(32),len(x))))
    for j,c in enumerate(CHANNELS):long[c]=sequences[:,:,j].reshape(-1)
    params=dict(MinimalFCParameters());params.update(autocorrelation=[{'lag':1},{'lag':2},{'lag':3}],
        mean_abs_change=None,absolute_sum_of_changes=None,linear_trend=[{'attr':'slope'}])
    print('TSFRESH START',len(long),flush=True)
    auto=extract_features(long,column_id='id',column_sort='step',default_fc_parameters=params,n_jobs=0,
                          disable_progressbar=True,show_warnings=False).sort_index()
    auto=auto.replace([np.inf,-np.inf],np.nan);auto.columns=['auto__'+c for c in auto.columns]
    auto.insert(0,'signal_id',x.signal_id.to_numpy());auto.to_csv(OUT/'automatic_features.csv',index=False)
    audit=dict(candidates=len(x),paired_labels=int(x.paired_eligible.sum()),rr1_ambiguous=int(x.rr1_both.sum()),
        rr12_ambiguous=int(x.rr12_both.sum()),causal_windows=len(audits),future_mutation=qa,
        automatic_feature_count=len(auto.columns)-1,source_hashes=hashes,channels=CHANNELS,tsfresh_parameters=params,
        no_calendar_or_spread_in_sequences=True,entry_bid_equals_m1_open=True)
    (OUT/'dataset_audit.json').write_text(json.dumps(audit,indent=2))
    print('PREPARED',audit['paired_labels'],'paired labels',flush=True)

def smoke():
    b=pd.DataFrame({'time':[0,60,120],'open':[10,10,10],'high':[10.5,11.1,11.3],'low':[9.5,9.5,8.5]})
    assert barrier(b,0,9,11)['outcome']=='TP'
    assert barrier(b,0,9,11.2)['outcome']=='AMBIGUOUS'
    assert barrier(b,0,8,12)['outcome']=='END_CENSORED'
    print('BARRIER SMOKE PASS')

if __name__=='__main__':
    import sys
    smoke() if '--smoke' in sys.argv else prepare()
