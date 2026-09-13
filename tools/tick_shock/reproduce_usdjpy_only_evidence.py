"""Audit shipped USDJPY subsets without the other five symbols or raw MT5 cache.

No model/threshold selection and no new holdout experiment. Reconstruct the
already frozen input matrices, refit only its specified development indices,
and compare deterministic predictions and independent trade selection.
"""
import json
import numpy as np
import pandas as pd
import usdjpy_only_ml as u
from audit_usdjpy_only_ml import recount_portfolio


def main():
    u.check_freeze();manifest=pd.read_csv(u.OUT/'input_subset_manifest.csv');fs=[];os=[];qa=[]
    for month in (202501,202502,202503,202504,202505,202506):
        pair=[]
        for kind in ('features','outcomes'):
            r=manifest[manifest.month.eq(month)&manifest.path.str.endswith(f'technical_{kind}.csv.gz')].iloc[0]
            path=u.ROOT/r.path;assert u.sha(path)==r.sha256
            frame=pd.read_csv(path);assert frame.symbol.eq('USDJPY').all()
            frame.episode_id=r.run_id+':'+frame.episode_id.astype(str)
            frame.market_cluster_id=r.run_id+':'+frame.market_cluster_id.astype(str)
            frame['month']=month
            if kind=='outcomes':frame['calendar_segment']=int(str(month)[-2:])-1
            pair.append(frame)
        fs.append(pair[0]);os.append(pair[1])
    f=pd.concat(fs).sort_values(['t0_msc','episode_id']).reset_index(drop=True);o=pd.concat(os,ignore_index=True)
    spec=json.loads((u.OUT/'frozen_model.json').read_text());cfg=spec['selection']
    x,_=u.s.core.feature_matrix(f.drop(columns='month'));x=x[spec['features']].to_numpy(float)
    group=o[o.distance_index.eq(spec['distance_index'])]
    indices=np.array(spec['fit_indices']);assert (f.loc[indices,'month']<202505).all()
    pair,_=u.s.fit_pair(cfg['family'],'NET_R',x,f,group,indices)
    predictions={side:pair[side].predict(x) for side in (1,-1)}
    for side in (1,-1):
        expected=u.export_predict(spec['models'][str(side)],x)
        delta=float(np.max(np.abs(predictions[side]-expected)))
        qa.append(dict(check=f'compressed_input_frozen_refit_{side}',rows=len(f),max_error=delta,status='PASS' if delta<1e-10 else 'FAIL'))
    for month in (202505,202506):
        ix=f.index[f.month.eq(month)].to_numpy();a=u.s.choose_actions(group,f.loc[ix],predictions[1][ix],predictions[-1][ix])
        ids=recount_portfolio(a,spec['threshold'])
        expected=pd.read_csv(u.OUT/f'holdout_{month}_trades.csv').episode_id.tolist()
        qa.append(dict(check=f'compressed_input_holdout_portfolio_{month}',rows=len(ids),max_error=0 if ids==expected else 1,status='PASS' if ids==expected else 'FAIL'))
    u.dump(qa,'portable_reproduction.csv');assert all(r['status']=='PASS' for r in qa)
    print(json.dumps(qa,indent=2))


if __name__=='__main__':main()
