"""Re-fit all 180 preregistered development folds from the shipped USDJPY subset.

No holdout file is read. Original evidence and model remain immutable.
"""
import json
import numpy as np
import pandas as pd
import usdjpy_only_ml as u


def main():
    u.check_freeze();original=u.OUT;target=original/'deterministic_full_replay'
    target.mkdir(exist_ok=False)
    (target/'tasks').mkdir();(target/'predictions').mkdir()
    manifest=pd.read_csv(original/'input_subset_manifest.csv');fs=[];os=[]
    for month in (202501,202502,202503,202504):
        for kind,storage in (('features',fs),('outcomes',os)):
            row=manifest[manifest.month.eq(month)&manifest.path.str.endswith(f'technical_{kind}.csv.gz')].iloc[0]
            assert u.sha(u.ROOT/row.path)==row.sha256
            f=pd.read_csv(u.ROOT/row.path).copy()
            f.episode_id=row.run_id+':'+f.episode_id.astype(str)
            f.market_cluster_id=row.run_id+':'+f.market_cluster_id.astype(str)
            f['month']=month
            if kind=='outcomes':f['calendar_segment']=int(str(month)[-2:])-1
            storage.append(f)
    f=pd.concat(fs).sort_values(['t0_msc','episode_id']).reset_index(drop=True);o=pd.concat(os,ignore_index=True)
    x,_=u.s.core.feature_matrix(f.drop(columns='month'))
    cols={'FULL486':list(range(486)),'SCALE_FREE':[i for i,n in enumerate(x) if not u.s.raw_scale_feature(n)]}
    u.DATA=(f,o,x.to_numpy(float),cols);u.OUT=target;checks=[]
    for path in sorted((original/'tasks').glob('*.json')):
        before=json.loads(path.read_text());ident=u.run_task(tuple(before['task']))
        after=json.loads((target/'tasks'/path.name).read_text())
        p0=np.load(original/'predictions'/f'{ident}.npz');p1=np.load(target/'predictions'/f'{ident}.npz')
        for key in ('indices','long_score','short_score'):
            error=float(np.max(np.abs(p0[key]-p1[key])))
            checks.append(dict(task=ident,check=key,max_error=error,status='PASS' if error<=1e-10 else 'FAIL'))
        for old,new in zip(before['rows'],after['rows']):
            assert old['policy']==new['policy']
            for key in ('threshold','trades','expectancy_r','pf','total_r','maxdd_r','neighbor_low','neighbor_high'):
                good=old[key]==new[key] if old[key] is None or new[key] is None else abs(old[key]-new[key])<=1e-10
                checks.append(dict(task=ident,check=old['policy']+'_'+key,max_error=0 if good else 1,status='PASS' if good else 'FAIL'))
        print('refit',ident,flush=True)
    u.OUT=original
    u.dump(checks,'full_deterministic_rerun.csv')
    u.js(dict(folds=180,checks=len(checks),failures=sum(r['status']=='FAIL' for r in checks),
        holdout_read=False,input='COMPRESSED_USDJPY_ONLY_SUBSETS',source_model_unchanged=True),'full_deterministic_rerun_summary.json')
    u.check_freeze();assert all(r['status']=='PASS' for r in checks)


if __name__=='__main__':main()
