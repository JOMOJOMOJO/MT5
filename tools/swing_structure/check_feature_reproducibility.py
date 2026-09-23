"""Verify native repetition, production immutability and unchanged READY universe."""
from pathlib import Path
import json,hashlib
import pandas as pd
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/feature_research'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    result={}
    manifest=json.loads((OUT/'production_manifest.json').read_text())
    result['production_unchanged']={p:digest(ROOT/p)==h for p,h in manifest.items()}
    result['repeated_csv']={}
    for left,right in [('smoke_fixed','smoke_repeat'),('discovery','discovery_repeat')]:
        for f in ['TW_features.csv','TW_feature_outcomes.csv']:
            result['repeated_csv'][left+'/'+f]={'identical':(OUT/left/f).read_bytes()==(OUT/right/f).read_bytes(),'sha256':digest(OUT/left/f)}
    result['ready_parity']={}
    for research,baseline in [('discovery','entry_train_current'),('replication','entry_holdout_current')]:
        a=pd.read_csv(OUT/research/'TW_features.csv');a=a[a.stage=='READY']
        b=pd.read_csv(OUT.parent/baseline/'TW_signals.csv')
        ak=set(zip(a.parent.astype(str),a.attempt.astype(str),a.signal_time))
        bk=set((x.signal_id.split('/')[0],x.signal_id.split('/')[1],x.signal_time) for x in b.itertuples())
        result['ready_parity'][research]={'observer_ready':len(a),'baseline_ready':len(b),'identical':ak==bk,'only_observer':sorted(ak-bk),'only_baseline':sorted(bk-ak)}
    result['no_order_calls']='OrderSend' not in (ROOT/'mql/Experts/USDJPY_3Wave_FeatureResearch.mq5').read_text()
    result['compile_clean']={p.name:'Result: 0 errors, 0 warnings' in p.read_text(encoding='utf-16') for p in OUT.glob('compile*.log')}
    gap=(OUT/'gap_audit.log').read_text(encoding='utf-8-sig')
    result['gap_audit']={'passed':'gaps=133 missed_candidates=0 errors=0' in gap,'scope':'Only these two windows; re-audit gaps for any future window.'}
    result['passed']=all(result['production_unchanged'].values()) and all(x['identical'] for x in result['repeated_csv'].values()) and all(x['identical'] for x in result['ready_parity'].values()) and result['no_order_calls'] and all(result['compile_clean'].values()) and result['gap_audit']['passed']
    (OUT/'reproducibility.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result))
    if not result['passed']:raise SystemExit(1)
if __name__=='__main__':main()
