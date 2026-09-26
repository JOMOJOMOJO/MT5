"""Attach causal descriptors to frozen native candidates, then validate native OHLC lineage."""
import json,hashlib
from pathlib import Path
import pandas as pd
import numpy as np
from three_wave_resistance import History,snapshot,seconds,unit_tests,TICK,SECONDS
R=Path(__file__).resolve().parents[2]
O=R/'reports/qa/three_wave/resistance_research';PREV=R/'reports/qa/three_wave/context_research'
PERIODS=['discovery','replication','extension']

def main():
    (O/'unit_tests.json').write_text(json.dumps(unit_tests(),indent=2))
    baseline=json.loads((O/'baseline_manifest.json').read_text())
    assert all(hashlib.sha256((R/p).read_bytes()).hexdigest()==h for p,h in baseline.items()),'Baseline mutated during research'
    export=pd.read_csv(O/'TW_resistance_export.csv');assert export.ok.all() and (export.tick_size==TICK).all()
    history=History(O);parity={}
    for period in PERIODS:
        old=pd.read_csv(PREV/period/'TW_context_bars.csv')
        for tf in ['M15','H1']:
            expected=old[old.tf==tf].drop(columns='tf')
            actual=history.raw[tf].merge(expected,on='time',suffixes=('_new','_old'),validate='one_to_one')
            assert len(actual)==len(expected)
            for field in ['open','high','low','close']:assert np.allclose(actual[field+'_new'],actual[field+'_old'],rtol=0,atol=1e-8),(period,tf,field)
            parity[period+'/'+tf]=len(actual)
    features=[];levels=[];clusters=[];prefix_tests=0
    for period in PERIODS:
        c=pd.read_csv(PREV/period/'TW_features.csv');when=seconds(c.signal_time)
        m1=history.raw['M1'].set_index('time');m5=history.raw['M5'].set_index('time')
        for k,(_,row) in enumerate(c.iterrows()):
            assert np.isclose(m1.loc[pd.Timestamp(int(when[k])-60,unit='s').strftime('%Y.%m.%d %H:%M:%S'),'close'],row.signal_close,atol=1e-8,rtol=0)
            assert np.isclose(m5.loc[row.m5_high_time,'high'],row.m5_high,atol=1e-8,rtol=0)
            for basis in ['STAGE','REVERSAL_CONTROL']:
                f,l,g=snapshot(history,row,int(when[k]),basis)
                features.append(dict(period=period,**f));levels.extend(dict(period=period,**x) for x in l);clusters.extend(dict(period=period,**x) for x in g)
            # Full-history vs physically truncated prefix, independent of cached results.
            if k%50==0:
                truncated=object.__new__(History);truncated.t={};truncated.h={};truncated.cache={}
                for tf in history.t:
                    keep=history.t[tf]<when[k];truncated.t[tf]=history.t[tf][keep];truncated.h[tf]=history.h[tf][keep]
                original=snapshot(history,row,int(when[k]),'STAGE')
                short=snapshot(truncated,row,int(when[k]),'STAGE')
                assert json.dumps(original,sort_keys=True)==json.dumps(short,sort_keys=True),'Future-prefix invariance'
                poisoned=object.__new__(History);poisoned.t=history.t;poisoned.h={};poisoned.cache={}
                for tf in history.t:
                    poisoned.h[tf]=history.h[tf].copy()
                    poisoned.h[tf][history.t[tf]+SECONDS[tf]>when[k]]=999999999
                changed_future=snapshot(poisoned,row,int(when[k]),'STAGE')
                assert json.dumps(original,sort_keys=True)==json.dumps(changed_future,sort_keys=True),'Forming/future high leaked'
                prefix_tests+=1
    f=pd.DataFrame(features);l=pd.DataFrame(levels);g=pd.DataFrame(clusters)
    assert not f.duplicated(['period','id','stop_basis']).any()
    assert (f.first_room_R>=0).all()
    f.to_csv(O/'resistance_features.csv',index=False);l.to_csv(O/'resistance_levels.csv',index=False);g.to_csv(O/'resistance_clusters.csv',index=False)
    audit={'passed':True,'feature_rows':len(f),'raw_candidates':len(f)//2,'level_rows':len(l),'cluster_rows':len(g),
           'prior_native_OHLC_rows_matched':parity,'physical_prefix_tests':prefix_tests,'forming_and_future_poison_tests':prefix_tests,'baseline_unchanged':True}
    (O/'feature_audit.json').write_text(json.dumps(audit,indent=2));print(json.dumps(audit))
if __name__=='__main__':main()
