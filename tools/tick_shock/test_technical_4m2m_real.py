import unittest
import pandas as pd
from analyze_technical_4m2m_real import select


class SelectionTests(unittest.TestCase):
    def rows(self, counts=(201,201), ev=(.1,.1), top=(2,2), concentration=(.2,.2)):
        return [dict(candidate_id=f'g1_TREE_{threshold}', method='TREE', distance_index=1,
                     threshold=threshold,month=month,trades=counts[n],expectancy_r=ev[n],
                     total_r=ev[n]*counts[n],pf=1.1 if ev[n]>0 else .9,
                     top5_removed_total_r=top[n],max_day_profit_share=concentration[n])
                for threshold in (0,.1) for n,month in enumerate((202503,202504))]

    def test_both_months_and_adjacent_threshold(self):
        front,chosen,verdict=select(self.rows())
        self.assertEqual(front.candidate_gate.sum(),2)
        self.assertEqual(verdict,'DEVELOPMENT_CANDIDATE')

    def test_average_frequency_not_enough(self):
        front,chosen,verdict=select(self.rows(counts=(199,999)))
        self.assertEqual(front.candidate_gate.sum(),0)
        self.assertEqual(chosen['min_month_trades'],199)
        self.assertTrue(verdict.startswith('DIAGNOSTIC'))

    def test_top_five_dependence_rejects(self):
        front,_,_=select(self.rows(top=(-.1,1)))
        self.assertFalse(front.candidate_gate.any())

    def test_concentration_rejects(self):
        front,_,_=select(self.rows(concentration=(.35,.2)))
        self.assertFalse(front.candidate_gate.any())

    def test_negative_month_rejects(self):
        front,_,_=select(self.rows(ev=(-.001,.5)))
        self.assertFalse(front.candidate_gate.any())

    def test_single_positive_cell_does_not_pass(self):
        rows=self.rows()
        for r in rows:
            if r['threshold']==.1:r.update(total_r=-1,expectancy_r=-.1,pf=.9)
        front,_,_=select(rows)
        self.assertFalse(front.candidate_gate.any())

    def test_missing_validation_month_fails_closed(self):
        with self.assertRaises(AssertionError):select([r for r in self.rows() if r['month']==202503])


if __name__=='__main__':unittest.main(verbosity=2)
