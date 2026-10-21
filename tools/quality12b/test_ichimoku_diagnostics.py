import unittest
from datetime import datetime,timedelta
from analyze_ichimoku_diagnostics import calculate

class IchimokuTests(unittest.TestCase):
    def bars(self):
        start=datetime(2025,1,1)
        return [dict(bar_time=(start+timedelta(minutes=15*i)).strftime('%Y.%m.%d %H:%M:%S'),
                     close_time=(start+timedelta(minutes=15*(i+1))).strftime('%Y.%m.%d %H:%M:%S'),
                     high=str(i+2),low=str(i),close=str(i+1)) for i in range(80)]
    def test_shift_and_midpoints(self):
        when=datetime(2025,1,1,20);s=calculate(self.bars(),when,when,90,2)
        self.assertEqual(s['tenkan'],76);self.assertEqual(s['kijun'],67.5)
        self.assertEqual(s['span_a'],46.75);self.assertEqual(s['span_b'],29.5)
        self.assertEqual(s['lag_high'],55);self.assertEqual(s['cloud_location'],'ABOVE')
    def test_future_mutation_invariance(self):
        b=self.bars();when=datetime(2025,1,1,20)
        s=calculate(b,when,when,90,2)
        f=dict(b[-1],close_time='2025.01.02 00:00:00',high='999999',low='-99999',close='5555')
        self.assertEqual(s,calculate(b+[f],when,when,90,2))
    def test_only_closed_bars(self):
        when=datetime(2025,1,1,19,59,59)
        self.assertIsNone(calculate(self.bars(),when,datetime(2025,1,1,19,45),90,2))
    def test_current_cloud_ignores_recent_26_bar_extremes(self):
        b=self.bars();when=datetime(2025,1,1,20);a=calculate(b,when,when,90,2)
        for x in b[55:]:x['high']='99999'
        z=calculate(b,when,when,90,2)
        self.assertEqual(a['span_a'],z['span_a']);self.assertEqual(a['span_b'],z['span_b'])
        self.assertNotEqual(a['tenkan'],z['tenkan'])
    def test_gap_uses_bar_count_not_wall_clock(self):
        b=self.bars();when=datetime(2025,1,6,0)
        z=calculate(b,when,when,90,2)
        self.assertEqual(z['cloud_source_bar'],b[54]['bar_time'])

if __name__=='__main__':unittest.main()
