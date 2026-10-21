import unittest
from analyze_cost_channel import ROOT,read,native
from portable_pair_audit import deal_difference,environment_rows
from analyze_portable_audit_r2 import deal_coverage

OLD=ROOT/'reports/qa/cost_channel_20261008_r2/runs/20261008_171544_bbf5d27f/daily_smoke'
NEW=ROOT/'reports/qa/portable_audit_20261009_r2/runs/20261009_153348_619497c2/daily_legacy_clock'

class PairedGateTests(unittest.TestCase):
    def test_real_swap_difference_still_fails_cash(self):
        a=deal_difference(read(OLD/'cost.csv',';'),read(NEW/'cost.csv',';'))
        self.assertTrue(a['execution_pass']);self.assertFalse(a['cash_pass']);self.assertEqual(len(a['cash_differences']),2)
    def test_actual_matching_exec_and_cash(self):
        r=read(NEW/'cost.csv',';');a=deal_difference(r,r)
        self.assertTrue(a['execution_pass']);self.assertTrue(a['cash_pass'])
    def test_price_difference_rejected(self):
        r=read(NEW/'cost.csv',';');c=[dict(x) for x in r];c[0]['price']=str(float(c[0]['price'])+.001)
        self.assertFalse(deal_difference(r,c)['execution_pass'])
    def test_missing_deal_not_tolerated(self):
        r=read(NEW/'cost.csv',';');self.assertFalse(deal_coverage(native(NEW/'report.htm')[2],r[:-1])['passed'])
    def test_changed_spec_never_passes(self):
        rows=[dict(phase='START',symbol='EURUSD',field='SYMBOL_SWAP_LONG',value='1'),
              dict(phase='CHANGE',symbol='EURUSD',field='SYMBOL_SWAP_LONG',value='2'),
              dict(phase='END',symbol='EURUSD',field='SYMBOL_SWAP_LONG',value='1')]
        a=environment_rows(rows,['EURUSD']);self.assertFalse(a['passed']);self.assertTrue(any('changed during' in e for e in a['errors']))
    def test_empty_environment_rejected(self):
        self.assertFalse(environment_rows([],['EURUSD'])['passed'])

if __name__=='__main__':unittest.main()
