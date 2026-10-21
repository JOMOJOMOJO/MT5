"""Check performance-only construction change against saved pre-change draws."""
import json
from pathlib import Path
import time
import pandas as pd
from tools.entry_research.multiasset.inference import random_controls

base=Path('reports/research/multiasset_20261016/full/USDJPY/M5')
cfg=json.loads(Path('tools/entry_research/multiasset/config.json').read_text())
f=pd.read_parquet(base/'features.parquet')
c=pd.read_parquet(base/'candidates.parquet')
events=c[c.method.eq('ichimoku_cloud') & c.side.eq('LONG') & c.comparison_eligible]
rows=[]
for kind in ['unconditional','conditional']:
    before=time.perf_counter()
    draws,audit=random_controls(f,events,kind,cfg)
    elapsed=time.perf_counter()-before
    old=pd.read_parquet(base/'ichimoku_cloud_LONG'/(kind+'_draws.parquet'))
    pd.testing.assert_frame_equal(draws[old.columns].reset_index(drop=True),old)
    oldaudit=pd.read_parquet(base/'ichimoku_cloud_LONG'/(kind+'_matching_audit.parquet'))
    pd.testing.assert_frame_equal(audit,oldaudit)
    rows.append({'kind':kind,'exact_draw_and_audit_match':True,'rows':len(draws),'seconds':elapsed})
Path('reports/research/multiasset_20261016/qa/control_optimization.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))
