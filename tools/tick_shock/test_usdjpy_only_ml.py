"""Hand-constructed regression tests for the USDJPY research orchestration."""
import unittest
import numpy as np
import pandas as pd
import usdjpy_only_ml as u
from audit_usdjpy_only_ml import recount_portfolio


def outcome(episode='a',side=1,status='TP',processing=100,entry=101,exit=200):
    return dict(episode_id=episode,symbol='USDJPY',direction=side,status=status,
        signal_processing_msc=processing,t0_msc=processing-1,entry_msc=entry,exit_msc=exit,
        market_cluster_id=episode,score=.1,gross_r=1.,distance=.1,pip_size=.01,
        gross_pips=10.,calendar_segment=0)


class ResearchTests(unittest.TestCase):
    def test_tie_no_trade(self):
        o=pd.DataFrame([outcome(side=1),outcome(side=-1)])
        f=pd.DataFrame({'episode_id':['a']})
        self.assertEqual(len(u.s.choose_actions(o,f,np.array([.2]),np.array([.2]))),0)

    def test_rejected_best_side_no_fallback(self):
        o=pd.DataFrame([outcome(side=1,status='COST_DISTANCE_REJECT'),outcome(side=-1)]).drop(columns='score')
        a=u.s.choose_actions(o,pd.DataFrame({'episode_id':['a']}),np.array([.3]),np.array([.1]))
        self.assertEqual(a.direction.tolist(),[1]);self.assertEqual(len(u.s.simulate(a,0)[0]),0)

    def test_causal_entry_reject(self):
        with self.assertRaises(ValueError):u.s.simulate(pd.DataFrame([outcome(entry=99)]),0)

    def test_single_position(self):
        a=pd.DataFrame([outcome('a'),outcome('b',processing=150,entry=151,exit=250),outcome('c',processing=201,entry=202,exit=300)])
        self.assertEqual(u.s.simulate(a,0)[0].episode_id.tolist(),['a','c'])
        self.assertEqual(recount_portfolio(a,0),['a','c'])

    def test_boundary_release_equal_is_busy(self):
        a=pd.DataFrame([outcome('a'),outcome('b',processing=200,entry=201,exit=300)])
        self.assertEqual(len(u.s.simulate(a,0)[0]),1)

    def test_linear_export_imputation(self):
        m=dict(kind='LINEAR',median=[2.,3.],mean=[1.,1.],scale=[2.,1.],coefficient=[.4,-.2],intercept=.1)
        self.assertAlmostEqual(u.export_predict(m,np.array([[np.nan,2.]]))[0],.1)

    def test_forest_float32_and_average(self):
        t=dict(left=[1,-1,-1],right=[2,-1,-1],feature=[0,-2,-2],threshold=[1.,-2.,-2.],value=[0.,-.5,.5])
        m=dict(kind='FOREST',median=[0.],trees=[t,t])
        np.testing.assert_allclose(u.export_predict(m,np.array([[1.],[1.+1e-9],[1.+1e-5]])),[-.5,-.5,.5])

    def test_lgb_additive(self):
        m=dict(kind='LIGHTGBM',median=[0.],trees=[{'leaf_value':.2},{'leaf_value':-.05}])
        self.assertAlmostEqual(u.export_predict(m,np.array([[1.]]))[0],.15)

    def test_raw_scale_exact_exclusion(self):
        self.assertTrue(u.s.raw_scale_feature('m5_atr14'))
        self.assertTrue(u.s.raw_scale_feature('quote_mid'))
        self.assertFalse(u.s.raw_scale_feature('m5_atr7_atr28'))
        self.assertFalse(u.s.raw_scale_feature('m5_ema20_price_gap_atr'))

    def test_only_past_full_label_available(self):
        boundary=1738368000000
        f=pd.DataFrame(dict(episode_id=['a','b','c'],market_cluster_id=['a','b','c'],
            month=[202501,202501,202502],t0_msc=[boundary-1000000,boundary-900000,boundary+100]))
        o=pd.DataFrame(dict(episode_id=['a','b','c'],exit_msc=[boundary-99999,boundary-1,boundary+1000],entry_msc=[boundary-1000000,boundary-900000,boundary+200]))
        result=u.split(f,o,202502)
        self.assertEqual(result['fit'].tolist(),[0]);self.assertEqual(result['val'].tolist(),[2])

    def test_cross_boundary_cluster_purged(self):
        b=1738368000000
        f=pd.DataFrame(dict(episode_id=['a','b'],market_cluster_id=['same','same'],month=[202501,202502],t0_msc=[b-2000000,b+1]))
        o=pd.DataFrame(dict(episode_id=['a','b'],exit_msc=[b-1000000,b+2],entry_msc=[b-2000000,b+1]))
        self.assertEqual(len(u.split(f,o,202502)['fit']),0)

    def test_policies_do_not_use_profit(self):
        a=pd.DataFrame([outcome(str(i),processing=i*1000+100,entry=i*1000+101,exit=i*1000+200) for i in range(40)])
        a['score']=np.linspace(-.1,.2,40)
        before=u.policies(a,1)
        a['gross_r']=999.;a['gross_pips']=-999.
        self.assertEqual(before,u.policies(a,1));self.assertEqual(len(before),12)

    def test_commission_stress_once(self):
        s=u.s.stats(pd.DataFrame([outcome()]),.2)
        self.assertAlmostEqual(s['expectancy_r'],.98)


if __name__=='__main__':unittest.main(verbosity=2)
