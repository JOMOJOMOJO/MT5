"""Only a proven cash-neutral historical swap difference is classified separately."""
import copy
import unittest
from analyze_wick_rebreak_r3 import classify_historical_environment


def fixture():
    specs={'USDJPY':dict(SYMBOL_SWAP_SHORT='1.71',SYMBOL_SWAP_LONG='6.5',SYMBOL_VOLUME_STEP='.01')}
    after=copy.deepcopy(specs);after['USDJPY']['SYMBOL_SWAP_SHORT']='1.70'
    inputs=dict(InpEnableRoundBucket='true',InpEnableRoundShortBucket='false',InpEnableDowSweepBucket='false')
    entry=dict(position_id='1',symbol='USDJPY',entry_kind='0',type='0',time_msc='1704189600000',price='150',volume='.1',sl='149',tp='151.5',
               profit='0',commission='0',swap='0',fee='0',quote_status='NONE',quote_msc='0',reason='3')
    exit_=dict(entry,entry_kind='1',type='1',time_msc='1704190200000',price='151.5',profit='10',sl='0',tp='0',reason='5')
    rows=[entry,exit_]
    return [specs,after,inputs,rows,copy.deepcopy(rows)]


class HistoricalSwapTests(unittest.TestCase):
    def test_difference_preserved(self):
        r=classify_historical_environment(*fixture())
        self.assertTrue(r['comparison_usable']);self.assertFalse(r['environment_exact'])
        self.assertEqual(len(r['specification_differences']),1)
    def reject(self,fn):
        x=fixture();fn(x);self.assertFalse(classify_historical_environment(*x)['comparison_usable'])
    def test_contract_drift_rejected(self):self.reject(lambda x:x[1]['USDJPY'].update(SYMBOL_VOLUME_STEP='.1'))
    def test_short_enabled_rejected(self):self.reject(lambda x:x[2].update(InpEnableRoundShortBucket='true'))
    def test_applied_swap_rejected(self):self.reject(lambda x:[r[1].update(swap='1') for r in x[3:]])
    def test_cash_difference_rejected(self):self.reject(lambda x:x[4][1].update(profit='9'))
    def test_fill_difference_rejected(self):self.reject(lambda x:x[4][1].update(price='151.4'))
    def test_overnight_rejected(self):self.reject(lambda x:[r[1].update(time_msc=str(int(r[1]['time_msc'])+86400000)) for r in x[3:]])
    def test_no_trades_not_proof(self):self.reject(lambda x:[r.clear() for r in x[3:]])
    def test_no_difference(self):
        x=fixture();x[1]=copy.deepcopy(x[0]);r=classify_historical_environment(*x)
        self.assertTrue(r['environment_exact']);self.assertTrue(r['comparison_usable'])


if __name__=='__main__':unittest.main()
