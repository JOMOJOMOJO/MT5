"""Audit causal feature snapshots and no-order shadow labels before any statistics."""
import json,sys,re
from pathlib import Path
import numpy as np
import pandas as pd
ROOT=Path(__file__).resolve().parents[2]/'reports/qa/three_wave/feature_research'

def audit(name):
    run=ROOT/name
    c=pd.read_csv(run/'TW_features.csv');o=pd.read_csv(run/'TW_feature_outcomes.csv')
    issues=[]
    def check(ok,msg):
        if not bool(ok):issues.append(msg)
    check(not c.id.duplicated().any(),'duplicate candidate id')
    check(not o.duplicated(['id','stop_basis']).any(),'duplicate shadow id/basis')
    check(set(o.id)==set(c.id) and len(o)==2*len(c),'missing or extra shadow labels')
    check(set(c.stage)<=set(['CHOCH','HL','READY']),'unknown stage')
    check(set(o.outcome)<=set(['TP','SL','TIMEOUT','END_CENSORED','INVALID_GEOMETRY']),'empty or unknown outcome')
    t=pd.to_datetime(c.signal_time,format='%Y.%m.%d %H:%M:%S')
    ms=t.astype('datetime64[ms]').astype('int64')
    check(((c.decision_msc>=ms)&(c.decision_msc<ms+60000)).all(),'decision outside first signal minute')
    for column in ['m5_feature_close','m5_origin_confirmed','m5_high_confirmed','m1_return_confirmed','m1_reversal_confirmed','m1_hl_confirmed','choch_confirmed','m1_wave1_confirmed']:
        v=pd.to_datetime(c[column],format='%Y.%m.%d %H:%M:%S',errors='coerce')
        check((v.isna()|(v<=t)).all(),'future value '+column)
    for stage,field in [('CHOCH','choch_confirmed'),('HL','m1_hl_confirmed')]:
        part=c[c.stage==stage]
        check((part.signal_time==part[field]).all(),stage+' not emitted at confirmation')
    check((c.feature_status=='OK').all(),'missing native indicator values')
    for field in ['down_er','wave1_er']:
        check(c[field].dropna().between(-1e-9,1+1e-9).all(),'ER outside [0,1] '+field)
    check((c.atr14>0).all(),'nonpositive ATR')
    equations={
        'ema_slope_atr':(c.ema20-c.ema_lag3)/(3*c.atr14),
        'ema_prior_slope_atr':(c.ema_lag3-c.ema_lag6)/(3*c.atr14),
        'ema_deceleration':c.ema_slope_atr-c.ema_prior_slope_atr,
        'ema_distance_atr':(c.signal_close-c.ema20)/c.atr14,
        'choch_break_strength':(c.choch_close-c.m1_return)/c.choch_atr_m1,
        'wave2_current_retracement':(c.m5_high-c.signal_close)/(c.m5_high-c.m5_origin)}
    for k,v in equations.items():check(np.allclose(c[k],v,atol=2e-8,equal_nan=True),'feature formula '+k)
    for _,part in c.groupby(['parent','attempt']):
        check(part.choch_break_strength.max()-part.choch_break_strength.min()<1e-8,'CHoCH strength not frozen')
    for basis in ['STAGE','REVERSAL_CONTROL']:
        q=c.merge(o[o.stop_basis==basis],on='id',validate='one_to_one')
        valid=q[~q.outcome.isin(['INVALID_GEOMETRY'])]
        anchor=q.m1_reversal if basis=='REVERSAL_CONTROL' else q.m1_hl.where(q.stage!='CHOCH',q.m1_reversal)
        check(np.allclose(q.sl,anchor-.01,atol=.001001),'SL anchor mismatch '+basis)
        check(np.allclose(q.entry,q.entry_ask,atol=1e-10),'entry not actual Ask '+basis)
        done=valid[valid.outcome.isin(['TP','SL','TIMEOUT'])]
        check((done.exit_msc>=done.entry_msc).all(),'exit before entry')
        tp=done[done.outcome=='TP'];sl=done[done.outcome=='SL']
        check(np.allclose(tp.result_R,(tp.tp-tp.entry)/tp.risk,atol=1e-8),'incorrect TP R')
        check((sl.result_R<=-1+1e-8).all(),'incorrect SL R')
        check((valid[['mfe_exit_R','mae_exit_R']].min()>=-1e-8).all(),'negative MFE/MAE')
        completed=valid[valid.complete60==True]
        check((completed.last_tick60<=completed.entry_msc+3600000).all(),'60-minute excursion includes later tick')
    log=(run/'tester.log').read_text(encoding='utf-8-sig')
    match=re.search(r'TW_FEATURE_RESULT candidates=(\d+) feature_errors=(\d+) data_skips=(\d+) orders_sent=0',log)
    check(match is not None,'missing recorder completion')
    if match:check(int(match[1])==len(c) and int(match[2])==0 and int(match[3])==0,'record count/errors/skipped bars')
    quality=[line.split('\t')[-1] for line in log.splitlines() if any(x in line for x in ['real ticks absent','real ticks discarded','tick prices mismatch'])]
    first=c.sort_values('signal_time').drop_duplicates(['parent','attempt','stage'])
    result={'run':name,'raw_candidates':len(c),'raw_by_stage':c.stage.value_counts().to_dict(),
        'primary_by_stage':first.stage.value_counts().to_dict(),'unique_parents':int(c.parent.nunique()),
        'unique_attempts':int(len(c[['parent','attempt']].drop_duplicates())),
        'outcomes':o.groupby(['stop_basis','outcome']).size().to_dict(),
        'missing_features':c.isna().sum().to_dict(),'data_quality_warnings':quality,'issues':issues}
    result['outcomes']={'/'.join(k):int(v) for k,v in result['outcomes'].items()}
    (run/'audit.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps({k:result[k] for k in ['run','raw_candidates','primary_by_stage','unique_parents','unique_attempts','outcomes','issues']}))
    return result

if __name__=='__main__':
    results=[audit(n) for n in sys.argv[1:]]
    if not results or any(x['issues'] for x in results):raise SystemExit(1)
