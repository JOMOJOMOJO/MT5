from pathlib import Path
import json,unittest
from analyze_short_ichimoku import short_shadow
from prepare_short_ichimoku import MIRROR,section

ROOT=Path(__file__).resolve().parents[2]
class ShortTests(unittest.TestCase):
    def candidate(self):return dict(time='1970.01.01 00:00:01',price='100',bid='100',ask='100.2',planned_sl='101',planned_tp='98.5')
    def path(self,op,hi,lo,cl,end='0'):
        return [dict(first_msc='1000',last_msc='2000',open_ask=str(op),high_ask=str(hi),low_ask=str(lo),close_ask=str(cl),horizon_end=end)]
    def test_profit_on_falling_ask(self):
        r=short_shadow(self.candidate(),self.path(100.2,100.3,98.5,98.6))
        self.assertEqual(r['shadow_outcome'],'TP');self.assertEqual(r['shadow_r'],1.5)
    def test_ask_stop_not_bid(self):
        # Bid could still be 100.8 while the liquidation Ask reaches SL 101.
        r=short_shadow(self.candidate(),self.path(100.2,101,99.5,100.8))
        self.assertEqual(r['shadow_outcome'],'SL');self.assertEqual(r['shadow_r'],-1)
    def test_spread_is_immediate_adverse_mark(self):
        r=short_shadow(self.candidate(),self.path(100.2,100.2,100.2,100.2,'1'))
        self.assertAlmostEqual(r['shadow_r'],-.2);self.assertAlmostEqual(r['horizon_mae_r'],-.2)
    def test_dual_touch_is_excluded(self):
        r=short_shadow(self.candidate(),self.path(100.2,101.2,98,100))
        self.assertEqual(r['shadow_outcome'],'AMBIGUOUS_M1');self.assertIsNone(r['shadow_r'])
    def test_adverse_gap_not_capped(self):
        r=short_shadow(self.candidate(),self.path(103,103,102.5,102.5))
        self.assertEqual(r['shadow_r'],-3);self.assertEqual(r['shadow_tp_capped_r'],-3)
    def test_all_mirrored_settings_match(self):
        v=json.loads((ROOT/'reports/qa/m5_short_ichimoku_20261007/frozen/inputs.json').read_text())
        for short,long in MIRROR.items():self.assertEqual(v[short],v[long])
        self.assertEqual(v['InpEnableRoundBucket'],'false');self.assertEqual(v['InpEnableRoundShortBucket'],'true')
        self.assertEqual(v['InpRiskPercent'],'0.65')
    def test_reuses_short_boolean_logic_and_execution(self):
        old=(ROOT/'reports/qa/m5_ichimoku_diagnostics_20261007/frozen/quality12b_snapshot.mq5').read_text()
        new=(ROOT/'reports/qa/m5_short_ichimoku_20261007/frozen/quality12b_snapshot.mq5').read_text()
        before=section(old,'bool EvaluateRoundShortSignal(','bool EvaluateRoundLooseSignal(')
        after=section(new,'bool EvaluateRoundShortSignal(','bool EvaluateRoundLooseSignal(')
        after=after.replace('return RecordRoundDecision("SHORT_CONDITION_NOT_MET");','return false;').replace('return RecordRoundDecision("SHORT_SIGNAL",true);','return true;')
        self.assertEqual(before,after)
        for name in ('Orders','PositionManagement'):
            start='// RELATIVE_CONTINUATION_MODULE_BEGIN '+name;end='// RELATIVE_CONTINUATION_MODULE_END '+name
            self.assertEqual(section(old,start,end),section(new,start,end))
        self.assertEqual(new.count('bool roundSignal=EvaluateRoundShortSignal(rates,fastEma,slowEma);'),1)
        self.assertNotIn('if(EvaluateRoundShortSignal(rates, fastEma, slowEma))',new)

if __name__=='__main__':unittest.main()
