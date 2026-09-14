"""Independent fixed-time label QA; no model fitting or holdout access."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd
from audit_two_stage_precision import precision_bounds


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--run',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True);a=parser.parse_args()
    f=pd.read_csv(a.run/'technical_features.csv');o=pd.read_csv(a.run/'technical_outcomes.csv')
    t=pd.read_csv(a.run/'fixed_time_outcomes.csv');b=pd.read_csv(a.baseline/'technical_features.csv')
    keys=['symbol','t0_msc'];f=f.set_index(keys).sort_index();b=b.set_index(keys).sort_index()
    checks={'feature_identity':f.index.equals(b.index),
        'time_row_unique':not t.duplicated(['episode_id','direction','horizon_seconds']).any(),
        'horizons':set(t.horizon_seconds)=={300,600,900},
        'directions':set(t.direction)=={-1,1}}
    columns=[c for c in f if c not in {'episode_id','event_id','market_cluster_id'}]
    checks['feature_parity']=checks['feature_identity'] and np.allclose(
        f[columns].to_numpy(float),b[columns].to_numpy(float),rtol=0,atol=1e-10,equal_nan=True)
    checks['cluster_parity']=checks['feature_identity'] and f.market_cluster_id.equals(b.market_cluster_id)
    before=pd.read_csv(a.baseline/'technical_outcomes.csv').set_index(keys+['direction','distance_index']).sort_index()
    after=o.set_index(keys+['direction','distance_index']).sort_index()
    checks['original_barrier_identity']=before.index.equals(after.index)
    numeric=[c for c in after.columns if c not in {'episode_id','status'}]
    checks['original_barrier_parity']=checks['original_barrier_identity'] and after.status.equals(before.status) and np.allclose(
        before[numeric].to_numpy(float),after[numeric].to_numpy(float),atol=1e-10,rtol=0,equal_nan=True)
    entered=o[o.entry_msc.gt(0)].drop_duplicates('episode_id').set_index('episode_id')
    checks['all_entered_tracked']=set(t.episode_id)==set(entered.index)
    checks['six_labels_per_entered']=t.groupby('episode_id').size().eq(6).all()
    checks['entry_matches_original']=t.entry_msc.eq(t.episode_id.map(entered.entry_msc)).all()
    checks['entry_causal']=t.entry_msc.ge(t.signal_processing_msc).all() and t.entry_msc.gt(t.t0_msc).all()
    v=t[t.status.eq('TIME')].copy();price=np.where(v.direction.eq(1),v.entry_ask,v.entry_bid)
    checks['exit_causal']=(v.exit_msc>=v.entry_msc+v.horizon_seconds*1000).all()
    _,error,bound=precision_bounds(v)
    checks['r_arithmetic']=bool(np.isfinite(error).all() and np.isfinite(bound).all() and (error<=bound).all())
    checks['pip_arithmetic']=np.allclose(v.gross_pips,v.direction*(v.exit_price-price)/v.pip_size,atol=1e-7,rtol=0)
    checks['statuses']=set(t.status)<= {'TIME','CENSORED'}
    result={'status':'PASS' if all(checks.values()) else 'FAIL','checks':{k:bool(v) for k,v in checks.items()},
        'rows':len(t),'episodes':len(f),'time_labels':len(v),'censored_labels':int(t.status.eq('CENSORED').sum()),
        'max_exit_lag_ms':float((v.exit_msc-v.entry_msc-v.horizon_seconds*1000).max()),
        'r_check':'Per-row analytical 12-decimal serialization bound; not fixed relaxed tolerance',
        'max_r_arithmetic_error':float(error.max()),
        'sha256':hashlib.sha256((a.run/'fixed_time_outcomes.csv').read_bytes()).hexdigest()}
    (a.run/'fixed_time_qa.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result));raise SystemExit(0 if result['status']=='PASS' else 2)


if __name__=='__main__':main()
