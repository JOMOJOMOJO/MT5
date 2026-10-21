import json
from pathlib import Path
import unittest
from analyze_multitf_diagnostics import verify_context,shadow,summary,spread_bin

ROOT=Path(__file__).resolve().parents[2]
class MultiTFTests(unittest.TestCase):
    def row(self):
        return dict(time='2025.07.07 09:30:00',decision_time='2025.07.07 09:30:00',
            asof='2025.07.07 09:30:00',break_time='2025.07.07 05:30:00',break_bar='2025.07.07 02:30:00',
            break_confirmed='2025.07.07 03:00:00',m15_reference_equal='1',range_valid='0',
            structure_high='144.628',structure_low='144.775',position='UNKNOWN',location='UNKNOWN',raw_position='',
            spread_price='.002',ask='145.072',bid='145.070',atr='.04',spread_atr='.05',server_hour='9')

    def test_inverted_range_kept_unknown(self):
        verify_context(self.row()) # Actual failed old-batch case, not a reason to drop a candidate.

    def test_future_information_rejected(self):
        r=self.row();r['break_confirmed']='2025.07.07 09:45:00'
        with self.assertRaises(AssertionError):verify_context(r)

    def test_outside_position_not_clipped(self):
        r=self.row();r.update(range_valid='1',history_complete='1',closed_bars='1199',
            structure_high='145',structure_low='144',price='145.5',raw_position='1.5',position='HIGH',location='ABOVE')
        verify_context(r)

    def candidate(self):return dict(time='1970.01.01 00:00:01',price='100',planned_sl='99',planned_tp='101.5')
    def path(self,op,hi,lo,cl,horizon='0'):
        return [dict(first_msc='1000',last_msc='2000',open_bid=str(op),high_bid=str(hi),low_bid=str(lo),close_bid=str(cl),horizon_end=horizon)]

    def test_dual_touch_excluded(self):
        r=shadow(self.candidate(),self.path(100,102,98,100))
        self.assertEqual(r['shadow_outcome'],'AMBIGUOUS_M1');self.assertIsNone(r['shadow_r'])

    def test_gap_diagnostic_caps_upside_only(self):
        gain=shadow(self.candidate(),self.path(105,105,104,104))
        loss=shadow(self.candidate(),self.path(97,98,97,98))
        self.assertEqual(gain['shadow_r'],5);self.assertEqual(gain['shadow_tp_capped_r'],1.5)
        self.assertEqual(loss['shadow_tp_capped_r'],-3)

    def test_horizon_and_end_censored_not_equal(self):
        p=self.path(100,100.5,99.5,100.2)
        self.assertIsNone(shadow(self.candidate(),p)['shadow_r'])
        p[0]['horizon_end']='1';self.assertAlmostEqual(shadow(self.candidate(),p)['shadow_r'],.2)

    def test_no_data_and_fixed_bins(self):
        self.assertEqual(summary([],False)['n'],0)
        self.assertEqual(spread_bin('.1'),'0_to_0.10')
        self.assertEqual(spread_bin('.2'),'0.10_to_0.20')

    def test_no_trade_hook_or_new_parameter(self):
        hook=(ROOT/'mql/Include/Research/RelativeMultiTFDiagnostics.mqh').read_text()
        self.assertNotIn('input ',hook);self.assertNotIn('trade.',hook)
        self.assertIn('if(r[i].time+secs>when) break;',hook)
        source=(ROOT/'reports/qa/m5_multitf_diagnostics_20261007/frozen/quality12b_snapshot.mq5').read_text()
        self.assertIn('if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;',source)
        self.assertNotIn('MCBeforeOrder',source)

if __name__=='__main__':unittest.main()
