import csv
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from analyze_m5_context import extended_stats,parity

ROOT=Path(__file__).resolve().parents[2]
PKG=ROOT/'reports/qa/m5_m15_context_20261007'

class M5ContextTests(unittest.TestCase):
    def test_gap_cap_does_not_hide_adverse_slippage(self):
        rows=[dict(net='650',implied_initial_r_price='10.6',planned_reward_r_price='1.5',tp_overshoot_initial_r='9.1'),
              dict(net='-150',implied_initial_r_price='-2.0',planned_reward_r_price='1.5',tp_overshoot_initial_r='0')]
        s=extended_stats(rows)
        self.assertEqual(s['net'],500)
        self.assertEqual(s['mean_tp_capped_price_r'],-.25)
        self.assertEqual(s['pf_tp_capped_price_r'],.75)
        self.assertEqual(s['overshoot_trades'],1)

    def test_empty_category_retained(self):
        self.assertIsNone(extended_stats([])['mean_tp_capped_price_r'])
        self.assertEqual(extended_stats([])['n'],0)

    def test_shared_classifier_and_closed_bar_contract(self):
        source=(PKG/'frozen/quality12b_snapshot.mq5').read_text()
        core=(ROOT/'mql/Include/M15Environment.mqh').read_text(encoding='utf-8-sig')
        self.assertIn(core,source)
        self.assertIn('if(r[i].time+900>when) break;',source)
        self.assertIn('M15EnvSnapshot s=mcPlan;',source)
        self.assertIn('if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;',source)

    def test_frozen_matrix_only_changes_named_controls(self):
        m=json.loads((PKG/'manifest.json').read_text())
        self.assertEqual(len(m['runs']),16)
        values=json.loads((PKG/'frozen/inputs.json').read_text())
        self.assertEqual(values['InpRiskPercent'],'0.65')
        self.assertEqual(values['InpSignalTimeframe'],'5')
        for r in m['runs']:
            self.assertTrue(set(r['overrides']) <= {'InpSignalTimeframe','InpM15ResearchPolicy','InpTargetRMultiple','InpMaxHoldBars'})

    def test_exact_report_parity_checker(self):
        ref=ROOT/'reports/qa/rc_search_20261007/runs/20261007_094431_0d639534/validate_c10'
        with tempfile.TemporaryDirectory() as d:
            out=Path(d);shutil.copyfile(ref/'trades.csv',out/'trades.csv')
            parity(out,ref/'report.htm')
            self.assertTrue(json.loads((out/'observer_parity.json').read_text())['passed'])

if __name__=='__main__':unittest.main()
