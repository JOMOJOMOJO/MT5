import unittest
from analyze_cost_channel import ROOT,read
from analyze_portable_audit_r4 import initial_snapshot_errors

FAILED=ROOT/'reports/qa/portable_audit_20261009_r3/runs/20261009_162416_5035696c/daily_reference/environment.csv'

class InitialSnapshotTests(unittest.TestCase):
    def test_actual_first_sample_false_alarms(self):
        self.assertEqual(initial_snapshot_errors(read(FAILED,';')),['AUDUSD','EURUSD','GBPUSD','USDJPY','XAUUSD'])
    def test_initial_then_change_is_a_valid_sequence(self):
        self.assertEqual(initial_snapshot_errors([dict(symbol='USDJPY',phase='START'),dict(symbol='USDJPY',phase='CHANGE')]),[])
    def test_start_for_another_symbol_does_not_hide_error(self):
        self.assertEqual(initial_snapshot_errors([dict(symbol='USDJPY',phase='START'),dict(symbol='EURUSD',phase='CHANGE')]),['EURUSD'])

if __name__=='__main__':unittest.main()
