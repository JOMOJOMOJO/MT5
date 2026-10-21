import unittest
from analyze_context_research import simulate,stats


def bar(op,hi,lo,cl,end='0'):
    return dict(open_bid=str(op),high_bid=str(hi),low_bid=str(lo),close_bid=str(cl),last_msc='1000',horizon_end=end)


class ExitScreen(unittest.TestCase):
    def test_tp(self):
        r=simulate(100,99,1.5,[bar(100,101.7,99.5,101.6)])
        self.assertEqual(r['outcome'],'TP');self.assertEqual(r['result_r'],1.5)

    def test_bid_spread_loss(self):
        r=simulate(100,99,1.5,[bar(99.8,100.1,98.9,99)])
        self.assertEqual(r['outcome'],'SL');self.assertEqual(r['result_r'],-1)

    def test_dual_touch_excluded(self):
        r=simulate(100,99,1.5,[bar(100,102,98,100)])
        self.assertEqual(r['outcome'],'AMBIGUOUS_M1');self.assertIsNone(r['result_r'])

    def test_gap_preserved(self):
        r=simulate(100,99,1.5,[bar(104,105,103,104)])
        self.assertEqual(r['result_r'],4)

    def test_price_grid_exact_touch(self):
        r=simulate(156.123,156.123-.22,1.5,[bar(156.12,156.453,156.11,156.4)])
        self.assertEqual(r['outcome'],'TP');self.assertEqual(r['tp'],156.453)

    def test_horizon_and_censor_distinct(self):
        self.assertEqual(simulate(100,99,1.5,[bar(100,100.5,99.5,100.2)])['outcome'],'END_CENSORED')
        self.assertEqual(simulate(100,99,1.5,[bar(100,100.5,99.5,100.2,'1')])['outcome'],'TIME')

    def test_invalid_structure_stop(self):
        self.assertEqual(simulate(100,101,1.5,[])['outcome'],'INVALID_STOP')

    def test_year_balance_not_trade_weight(self):
        rows=[dict(year='2024',result_r=-1,outcome='SL',sl_pips=22)]+[dict(year='2025',result_r=1,outcome='TP',sl_pips=22) for _ in range(9)]
        s=stats(rows)
        self.assertEqual(s['equal_year_mean_r'],0);self.assertEqual(s['expectancy_price_r'],.8)


if __name__=='__main__':unittest.main()
