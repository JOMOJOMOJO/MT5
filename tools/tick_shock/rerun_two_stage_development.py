"""Fresh full-fold refit, never a new search or a holdout evaluation."""
from concurrent.futures import ProcessPoolExecutor,as_completed
import json
from pathlib import Path
import numpy as np
import two_stage_ml as s

def main():
    base=s.OUT;dest=base/'deterministic_replay'
    if dest.exists():raise FileExistsError(dest)
    freeze=json.loads((base/'python_freeze.json').read_text())
    assert s.sha(s.__file__)==freeze['driver_sha256']
    dest.mkdir();(dest/'predictions').mkdir();(dest/'tasks').mkdir()
    tasks=[(fam,var,h,m) for fam in s.core.FAMILIES for var in s.core.VARIANTS for h in s.HORIZONS for m in s.MONTHS[1:]]
    checks=[]
    with ProcessPoolExecutor(max_workers=3,initializer=s.init_worker,initargs=(base/'dataset.pkl',dest)) as pool:
        futures={pool.submit(s.run_task,t):t for t in tasks}
        for future in as_completed(futures):
            future.result();task=futures[future];name=s.task_id(task)
            for suffix in ('','_trades'):
                old=np.load(base/'predictions'/f'{name}{suffix}.npz');new=np.load(dest/'predictions'/f'{name}{suffix}.npz')
                assert set(old.files)==set(new.files)
                for key in old.files:
                    a,b=old[key],new[key];exact=a.dtype.kind in 'iu'
                    okay=np.array_equal(a,b) if exact else np.allclose(a,b,atol=1e-10,rtol=0,equal_nan=True)
                    checks.append(dict(task=name,field=suffix+key,status='PASS' if okay else 'FAIL'))
    s.dump(checks,'deterministic_rerun.csv')
    failures=sum(c['status']=='FAIL' for c in checks)
    s.js(dict(tasks=len(tasks),checks=len(checks),failures=failures,holdout_read=False),'deterministic_rerun_summary.json')
    assert failures==0

if __name__=='__main__':main()
