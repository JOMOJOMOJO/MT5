import json
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

from tools.entry_research.multiasset.inference import adjust_family, calendar_weights, distributions

CONFIG=json.loads(Path('tools/entry_research/multiasset/config.json').read_text())


def test_holm_resolution_and_shared_week_resampling():
    assert CONFIG['hypothesis_cells']*3/(CONFIG['bootstrap_reps']+1) < .05
    weeks, a=calendar_weights(CONFIG)
    _, b=calendar_weights(CONFIG)
    np.testing.assert_array_equal(a,b)
    assert (a.sum(axis=1)==len(weeks)).all()


def test_baseline_replicates_are_means_not_additional_samples():
    config=dict(CONFIG,baseline_repeats=2)
    strategy=pd.DataFrame({'week':['a','b'],'net_atr':[2.,4.]})
    controls=pd.DataFrame({'week':['a','b']*4,'net_atr':[1.,3.,1.,3.,1.,3.,1.,3.],
                           'replicate':[0,0,1,1]*2,'baseline_kind':['unconditional']*4+['conditional']*4})
    s,u,c=distributions(strategy,controls,['a','b'],np.array([[1,1],[2,0],[0,2]]),config)
    np.testing.assert_allclose(s,[3,2,4]); np.testing.assert_allclose(u,1); np.testing.assert_allclose(c,1)


def test_family_reserves_missing_markets():
    row={'sample_gate':True,'annual_gate':True}
    for n in ['net','delta_unconditional','delta_conditional']:
        row[n+'_p']=.001; row[n+'_ci_low']=.1
    result=adjust_family(pd.DataFrame([row]),CONFIG)
    assert not result.exploratory_hypothesis_pass.iloc[0]
    assert result.net_holm.iloc[0] == .648


def test_duckdb_reserved_table_roundtrip(tmp_path):
    frame=pd.DataFrame({'n':[3],'net_atr':[-.1]})
    with duckdb.connect(str(tmp_path/'r.duckdb')) as db:
        db.register('frame',frame)
        db.execute('CREATE TABLE "primary" AS SELECT * FROM frame')
        assert db.execute('SELECT n FROM "primary"').fetchone()[0]==3
