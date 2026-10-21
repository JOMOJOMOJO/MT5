import json
import tempfile
import unittest
from pathlib import Path
from analyze_reports import analyze_report, decode_report
from tick_quality import audit, header_percent

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / 'reports/qa/quality12b_revalidation_20261005/runs/20261005_120836_15208538'
OLD = ROOT / 'reports/backtest/imported/usdjpy_20260402_round_continuation_long-quality12b_guarded-train-9m-m15.htm'


class QualityTests(unittest.TestCase):
    def test_percent_not_keyword(self):
        self.assertEqual(header_percent('0% リアルティック'), 0)
        self.assertEqual(header_percent('14% real ticks'), 14)
        self.assertEqual(header_percent('100% リアルティック'), 100)
        self.assertIsNone(header_percent('100%'))

    def test_partial_headers_rejected(self):
        text = decode_report(OLD.read_bytes())
        for pct in (0, 14, 99):
            with self.subTest(pct=pct), tempfile.TemporaryDirectory() as d:
                p = Path(d) / 'mutated.htm'
                p.write_text(text.replace('100% リアルティック', f'{pct}% リアルティック'), encoding='utf-8')
                m, _ = analyze_report(p, require_real_ticks=True)
                self.assertFalse(m['audit']['passed'])

    def result(self, name):
        d = BATCH / name
        m = json.loads((d / 'metrics.json').read_text(encoding='utf-8-sig'))
        return audit(m['report'], d / 'journals/Tester')

    def test_rounded_100_fallback_rejected(self):
        q = self.result('reproduce_train')
        self.assertEqual(q['header_real_tick_percent'], 100)
        self.assertFalse(q['strict_real_tick_pass'])
        self.assertEqual(q['category'], 'MIXED_TICKS')

    def test_previous_run_warnings_excluded(self):
        for name in ('reproduce_check', 'recent_2026_apr_sep'):
            with self.subTest(name=name):
                q = self.result(name)
                self.assertTrue(q['strict_real_tick_pass'], q)
                self.assertEqual(q['matching_execution_blocks'], 1)

    def test_old_generated_data(self):
        q = self.result('annual_2018')
        self.assertFalse(q['strict_real_tick_pass'])
        self.assertEqual(q['category'], 'GENERATED_TICKS')

    def test_missing_journal_rejected(self):
        m = json.loads((BATCH / 'recent_2026_apr_sep/metrics.json').read_text(encoding='utf-8-sig'))
        with tempfile.TemporaryDirectory() as d:
            self.assertFalse(audit(m['report'], Path(d))['strict_real_tick_pass'])

    def test_grid_period_requires_unique_execution_tag(self):
        report=dict(expert='example',from_date='2023.01.01',to_date='2025.01.01',
                    model_quality='100% real ticks',inputs={'InpTelemetryFileName':'second.csv'})
        start='testing of Experts/example.ex5 from 2023.01.01 00:00 to 2025.01.01 00:00 started with inputs:\n'
        text=start+'InpTelemetryFileName=first.csv\nreal ticks absent\ntest example thread finished\n'
        text+=start+'InpTelemetryFileName=second.csv\ntest example thread finished\n'
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'Agent-1/logs';p.mkdir(parents=True)
            (p/'log.log').write_text(text)
            self.assertTrue(audit(report,Path(d))['strict_real_tick_pass'])
            report.pop('inputs')
            self.assertFalse(audit(report,Path(d))['strict_real_tick_pass'])


if __name__ == '__main__':
    unittest.main()
