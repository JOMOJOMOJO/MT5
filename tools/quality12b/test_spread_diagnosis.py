import unittest
from analyze_spread_diagnosis import classify


class CauseClassification(unittest.TestCase):
    def quote(self, bid, ask, **overrides):
        raw=(ask-bid)/0.01
        row=dict(tick_ok='1',pip='0.0100000000000000',point='0.0010000000000000',
                 bid=format(bid,'.16f'),ask=format(ask,'.16f'),raw_spread_pips=format(raw,'.16f'),
                 raw_allowed=str(int(0<=raw<=2)),limit_pips='2.0000000000000000')
        row.update(overrides)
        return row

    def test_exact_20_points_binary_roundoff_is_not_true_excess(self):
        row=self.quote(157.0,157.02)
        self.assertEqual(row['raw_allowed'],'0')
        self.assertEqual(classify(row),'FLOAT_BOUNDARY_ONLY')

    def test_21_points_is_true_excess(self):
        self.assertEqual(classify(self.quote(157.0,157.021)),'ABOVE_LIMIT')

    def test_19_points_passes(self):
        self.assertEqual(classify(self.quote(157.0,157.019)),'PASS')

    def test_api_failure(self):
        self.assertEqual(classify(self.quote(0,0,tick_ok='0',pip='0',raw_spread_pips='-1')),'TICK_API_FAILURE')

    def test_invalid_pip(self):
        self.assertEqual(classify(self.quote(157,157.02,pip='0',raw_spread_pips='-1')),'INVALID_PIP')

    def test_negative_spread(self):
        self.assertEqual(classify(self.quote(157.02,157)),'NEGATIVE_SPREAD')


if __name__=='__main__':
    unittest.main()
