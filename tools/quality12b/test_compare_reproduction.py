import tempfile
import unittest
from pathlib import Path
from compare_reproduction import compare
from analyze_reports import decode_report

ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT / 'reports/backtest/imported/usdjpy_20260402_round_continuation_long-quality12b_guarded-train-9m-m15.htm'
NEW = ROOT / 'reports/qa/quality12b_revalidation_20261005/runs/20261005_114938_50e3b4ee/reproduce_train/report.htm'


class ComparisonTests(unittest.TestCase):
    def test_exact(self):
        result = compare(OLD, OLD)
        self.assertTrue(result['passed'])
        self.assertEqual(result['classification'], 'EXACT_EXECUTIONS_AND_COSTS')

    def test_observed_swap_only(self):
        result = compare(OLD, NEW)
        self.assertTrue(result['passed'], result['errors'])
        self.assertEqual(result['net_delta'], -6.89)
        self.assertEqual(result['swap_delta'], -6.89)
        self.assertEqual(len(result['swap_difference_trades']), 9)
        self.assertEqual(result['core_trade_differences'], [])

    def test_price_change_rejected(self):
        text = decode_report(NEW.read_bytes())
        self.assertIn('149.421', text)
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'changed.htm'
            path.write_text(text.replace('149.421', '149.422'), encoding='utf-8')
            self.assertFalse(compare(OLD, path)['passed'])

    def test_input_change_rejected(self):
        text = decode_report(NEW.read_bytes())
        self.assertIn('InpTargetRMultiple=1.5', text)
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'changed.htm'
            path.write_text(text.replace('InpTargetRMultiple=1.5', 'InpTargetRMultiple=1.6'), encoding='utf-8')
            self.assertFalse(compare(OLD, path)['passed'])


if __name__ == '__main__':
    unittest.main()
