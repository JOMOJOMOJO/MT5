"""Independent accounting of every saved forward policy, no estimator fitting."""
import json
import numpy as np
import pandas as pd
import usdjpy_only_ml as u
from audit_usdjpy_only_ml import recount_portfolio
from technical_discovery_independent_recalculation import aggregate


def main():
    u.check_freeze();data=u.read_data();checks=[]
    for path in sorted((u.OUT/'tasks').glob('*.json')):
        obj=json.loads(path.read_text());cfg={k:obj[k] for k in ('family','target','variant','geometry')}
        a=u.actions(cfg,obj['month'],data)
        for row in obj['rows']:
            ids=recount_portfolio(a,row['threshold'])
            tr=a.set_index('episode_id',drop=False).loc[ids].reset_index(drop=True)
            stats=aggregate(tr.to_dict('records'),.2)
            for metric in ('trades','tp','sl','timeout','total_r','expectancy_r','pf','maxdd_r'):
                expected=row[metric];actual=stats[metric]
                if expected is None: ok=pd.isna(actual) or np.isinf(actual)
                else:ok=abs(actual-expected)<=1e-7
                checks.append(dict(task=path.stem,policy=row['policy'],metric=metric,
                    expected=expected,actual=actual,status='PASS' if ok else 'FAIL'))
        print('recount',path.stem,flush=True)
    u.dump(checks,'all_forward_independent_recalculation.csv')
    u.js(dict(checks=len(checks),failures=sum(r['status']=='FAIL' for r in checks),
        uses_full_precision_task_thresholds=True,estimator_fitting=False),'all_forward_recalculation_summary.json')
    assert all(r['status']=='PASS' for r in checks)


if __name__=='__main__':main()
