import copy
import tempfile
import unittest
from pathlib import Path
from analyze_cost_channel import ROOT, read
from portable_risk_audit import audit_risk, minute_key
from prepare_portable_audit import sha
from prepare_portable_audit_r5 import copy_verified_run

RUN = ROOT / 'reports/qa/portable_audit_20261009_r4/runs/20261012_113626_a789b4ef/m5_USDJPY_portable'


class RiskAuditTests(unittest.TestCase):
    def setUp(self):
        self.rows = read(RUN / 'risk.csv', ';')
        self.deals = read(RUN / 'cost.csv', ';')
        self.percent = float(dict(line.split('=', 1) for line in (RUN / 'inputs.set').read_text().splitlines() if '=' in line)['InpRiskPercent'])
        self.rejected = copy.deepcopy(next(r for r in self.rows if r['reason'] == 'NORMALIZED_VOLUME_EXCEEDS_RISK'))

    def test_actual_49_accepted_3_denied(self):
        result = audit_risk(self.rows, self.deals, self.percent)
        self.assertEqual(result['risk_reasons'], {'OK': 49, 'NORMALIZED_VOLUME_EXCEEDS_RISK': 3})
        self.assertEqual(len(result['normalized_risk_rejections']), 3)

    def test_rejection_below_budget_fails(self):
        self.rejected['planned_loss'] = self.rejected['budget']
        with self.assertRaises(AssertionError): audit_risk([self.rejected], self.deals, self.percent)

    def test_rejected_minute_entry_fails(self):
        entry = dict(symbol=self.rejected['symbol'], entry_kind='0', time_msc=str(minute_key(self.rejected['time']) * 60000 + 4321))
        with self.assertRaises(AssertionError): audit_risk([self.rejected], self.deals + [entry], self.percent)

    def test_other_symbol_entry_does_not_conflict(self):
        entry = dict(symbol='EURUSD', entry_kind='0', time_msc=str(minute_key(self.rejected['time']) * 60000))
        audit_risk([self.rejected], self.deals + [entry], self.percent)

    def test_accepted_oversized_plan_fails(self):
        self.rejected['reason'] = 'OK'
        with self.assertRaises(AssertionError): audit_risk([self.rejected], self.deals, self.percent)

    def test_unknown_failure_still_fails(self):
        self.rejected['reason'] = 'PROFIT_RECHECK_FAILED'
        with self.assertRaises(AssertionError): audit_risk([self.rejected], self.deals, self.percent)

    def test_nonfinite_fails(self):
        self.rejected['planned_loss'] = 'nan'
        with self.assertRaises(AssertionError): audit_risk([self.rejected], self.deals, self.percent)

    def test_zero_trade_minimum_lot_rejection(self):
        row = copy.deepcopy(self.rejected)
        row.update(reason='MIN_VOLUME_EXCEEDS_RISK', volume='0', planned_loss='0', budget='0.01')
        result = audit_risk([row], [], self.percent)
        self.assertEqual(result['risk_reasons'], {'MIN_VOLUME_EXCEEDS_RISK': 1})


class ReuseTests(unittest.TestCase):
    def test_verified_copy_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            source, target = Path(temp) / 'old', Path(temp) / 'new'
            source.mkdir();(source / 'report.htm').write_text('locked raw report')
            hashes = {'report.htm': sha(source / 'report.htm')}
            copy_verified_run(source, target, hashes)
            self.assertEqual(sha(source / 'report.htm'), sha(target / 'report.htm'))
            with self.assertRaises(AssertionError): copy_verified_run(source, target, hashes)

    def test_tampered_source_never_copied(self):
        with tempfile.TemporaryDirectory() as temp:
            source, target = Path(temp) / 'old', Path(temp) / 'new'
            source.mkdir();(source / 'report.htm').write_text('locked')
            hashes = {'report.htm': sha(source / 'report.htm')}
            (source / 'report.htm').write_text('changed')
            with self.assertRaises(AssertionError): copy_verified_run(source, target, hashes)
            self.assertFalse(target.exists())


if __name__ == '__main__': unittest.main()
