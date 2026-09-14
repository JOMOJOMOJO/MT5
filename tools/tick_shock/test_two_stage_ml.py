import unittest
from unittest.mock import patch
from pathlib import Path
import tempfile
import numpy as np
import pandas as pd
import two_stage_ml as t
from audit_two_stage_precision import precision_bounds


class CausalTests(unittest.TestCase):
    def test_current_score_not_in_reference(self):
        result=t.rolling_thresholds([0,100],[1.,3.],[200,300],[100.,-100.],.5)
        np.testing.assert_array_equal(result,[2.,3.])

    def test_equal_time_group_is_causal(self):
        result=t.rolling_thresholds([0,100],[1.,3.],[200,200,300],[100.,200.,-100.],.5)
        np.testing.assert_array_equal(result,[2.,2.,51.5])

    def test_expired_scores_not_in_reference(self):
        np.testing.assert_array_equal(t.rolling_thresholds([0,30*86400000],[100.,2.],[30*86400000+1],[3.],.5),[2.])

    def rows(self):
        return pd.DataFrame([
            dict(episode_id='a',signal_processing_msc=1000,t0_msc=999,entry_msc=1001,exit_msc=301001,
                horizon_seconds=300,status='TIME',score=.2,stage1_score=1.),
            dict(episode_id='b',signal_processing_msc=2000,t0_msc=1999,entry_msc=2001,exit_msc=302001,
                horizon_seconds=300,status='TIME',score=.3,stage1_score=1.),
            dict(episode_id='c',signal_processing_msc=301002,t0_msc=301001,entry_msc=301003,exit_msc=601003,
                horizon_seconds=300,status='TIME',score=.4,stage1_score=1.)])

    def test_one_position(self):
        self.assertEqual(t.select_trades(self.rows(),0,0).episode_id.tolist(),['a','c'])

    def test_gate_before_position_reservation(self):
        a=self.rows();a.loc[0,'stage1_score']=-1
        self.assertEqual(t.select_trades(a,0,0).episode_id.tolist(),['b'])

    def test_reject_noncausal_time_exit(self):
        a=self.rows();a.loc[0,'exit_msc']=301000
        with self.assertRaises(ValueError):t.select_trades(a,0,0)

    def test_no_gate_is_not_train_minimum(self):
        self.assertEqual(t.gate_value(np.array([1.,2.]),0),-np.inf)

    def test_stage_targets_cost_once_and_best_side(self):
        class Capture:
            def __init__(self,*args):pass
            def fit(self,x,y,status):self.y=y;return self
        f=pd.DataFrame({'episode_id':['a','b']});records=[]
        for eid,l,s in [('a',1.,-.5),('b',-.25,.75)]:
            for side,r in [(1,l),(-1,s)]:
                records.append(dict(episode_id=eid,direction=side,horizon_seconds=300,status='TIME',
                    gross_r=r,atr14_m5=.1,pip_size=.01))
        # 0.2 pip / 10 pip ATR = 0.02R. These are hand-specified targets.
        with patch.object(t.core,'ActionModel',Capture):
            models=t.fit_models('LOGISTIC',np.zeros((2,2)),f,pd.DataFrame(records),np.array([0,1]),300)
        np.testing.assert_allclose(models['long'].y,[.98,-.27],rtol=0,atol=1e-15)
        np.testing.assert_allclose(models['short'].y,[-.52,.73],rtol=0,atol=1e-15)
        np.testing.assert_allclose(models['stage1'].y,[.98,.73],rtol=0,atol=1e-15)

    def test_forward_pipeline_synthetic_smoke(self):
        random=np.random.default_rng(123);x=random.normal(size=(150,3));events=[];labels=[]
        for i in range(150):
            month=202501 if i<100 else 202502
            start=1735689600000 if i<100 else 1738368000000
            time=start+(i%100)*3600000;eid=f'e{i}'
            events.append(dict(episode_id=eid,market_cluster_id=eid,symbol='TEST',month=month,
                t0_msc=time,t0_processing_msc=time+1))
            for h in t.HORIZONS:
                for side in (1,-1):
                    r=float(.1*x[i,0]+side*.2*x[i,1]-.1)
                    labels.append(dict(episode_id=eid,market_cluster_id=eid,symbol='TEST',month=month,
                        t0_msc=time,signal_processing_msc=time+1,entry_msc=time+2,exit_msc=time+2+h*1000,
                        direction=side,horizon_seconds=h,status='TIME',gross_r=r,gross_pips=r*10,
                        pip_size=.01,atr14_m5=.1,distance=.1,calendar_segment=month-202501))
        data=(pd.DataFrame(events),pd.DataFrame(labels),x,{'FULL486':[0,1,2]},['x','y','z'])
        with tempfile.TemporaryDirectory() as directory,patch.object(t,'DATA',data),patch.object(t,'OUT',Path(directory)):
            (t.OUT/'predictions').mkdir();(t.OUT/'tasks').mkdir()
            rows=t.run_task(('LOGISTIC','FULL486',300,202502))
            self.assertEqual(len(rows),48)
            self.assertTrue(all(row['fit_n']==100 for row in rows))
            self.assertTrue(all(row['validation_n']==50 for row in rows))

    def test_precision_bound_does_not_accept_wrong_r(self):
        f=pd.DataFrame([dict(direction=1,entry_bid=1.,entry_ask=1.0001,exit_price=1.0002,atr14_m5=.0001,gross_r=2.)])
        computed,error,bound=precision_bounds(f)
        self.assertAlmostEqual(computed[0],1.)
        self.assertGreater(error[0],bound[0])


if __name__=='__main__':unittest.main()
