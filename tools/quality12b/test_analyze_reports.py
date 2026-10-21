"""Real-report reconciliation plus rejection of ambiguous report evidence."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).with_name("analyze_reports.py")
spec = importlib.util.spec_from_file_location("analyze_reports", MODULE)
analyzer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(analyzer)
ROOT = MODULE.parents[2]
REPORTS = ROOT / "reports/backtest/imported"
PREFIX = "usdjpy_20260402_round_continuation_long-quality12b_guarded-"


class ReportTests(unittest.TestCase):
    def path(self, period):
        return REPORTS / (PREFIX + period + "-m15.htm")

    def test_real_train_report(self):
        metrics, trades = analyzer.analyze_report(self.path("train-9m"), expect_symbol="USDJPY",
                                                  expect_timeframe="M15", expect_from="2025.04.01",
                                                  expect_to="2025.12.31", require_real_ticks=True)
        self.assertTrue(metrics["audit"]["passed"], metrics["audit"])
        self.assertEqual(len(trades), 60)
        self.assertEqual(len(metrics["report"]["inputs"]), 163)
        self.assertEqual(metrics["report"]["inputs"]["InpRiskPercent"], "0.65")
        self.assertEqual(metrics["calculated"]["net_profit"], 914.94)
        largest = metrics["largest_positive_trade"]
        self.assertEqual(largest["net"], 574.99)
        self.assertEqual(largest["entry_time"], "2025-10-03 20:45:00")
        self.assertEqual(largest["exit_time"], "2025-10-06 00:01:00")
        self.assertEqual(largest["initial_tp"], 147.761)
        self.assertEqual(largest["exit_price"], 149.421)
        self.assertEqual(largest["swap"], 2.31)
        self.assertTrue(largest["weekend_flag_calendar_heuristic"])
        self.assertAlmostEqual(largest["tp_overshoot_price"], 1.660)
        self.assertAlmostEqual(largest["implied_initial_r_price"], 1.990 / .220)
        self.assertEqual(metrics["static_excluding_largest_trade"]["net_profit"], 339.95)
        self.assertFalse(metrics["static_excluding_largest_trade"]["is_backtest"])

    def test_real_oos_report(self):
        metrics, trades = analyzer.analyze_report(self.path("oos-3m"), require_real_ticks=True)
        self.assertTrue(metrics["audit"]["passed"], metrics["audit"])
        self.assertEqual(len(trades), 9)
        self.assertEqual(metrics["calculated"]["net_profit"], 113.20)

    def mutated(self, old, new, **kwargs):
        content = analyzer.decode_report(self.path("train-9m").read_bytes())
        self.assertIn(old, content)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "mutated.htm"
            path.write_text(content.replace(old, new, 1), encoding="utf-8")
            return analyzer.analyze_report(path, **kwargs)

    def test_partial_exit_rejected(self):
        metrics, _ = self.mutated("<td>out</td><td>0.43</td>", "<td>out</td><td>0.20</td>")
        self.assertFalse(metrics["audit"]["passed"])
        self.assertGreater(metrics["audit"]["unpaired_entry_count"], 0)
        self.assertTrue(any("partial volume" in e for e in metrics["audit"]["errors"]))

    def test_overlap_rejected(self):
        metrics, _ = self.mutated("<td>out</td>", "<td>in</td>")
        self.assertFalse(metrics["audit"]["passed"])
        self.assertTrue(any("Overlapping entries" in e for e in metrics["audit"]["errors"]))

    def test_missing_real_ticks_rejected_when_required(self):
        metrics, _ = self.mutated("100% リアルティック", "100%", require_real_ticks=True)
        self.assertFalse(metrics["audit"]["passed"])
        self.assertFalse(metrics["report"]["real_ticks_claim"])

    def test_identity_mismatch_rejected(self):
        metrics, _ = analyzer.analyze_report(self.path("train-9m"), expect_from="2025.01.01")
        self.assertFalse(metrics["audit"]["passed"])
        self.assertTrue(any("Header mismatch from_date" in e for e in metrics["audit"]["errors"]))


if __name__ == "__main__":
    unittest.main()
