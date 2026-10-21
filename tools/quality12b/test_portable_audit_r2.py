import unittest
from analyze_portable_audit_r2 import deal_coverage
from analyze_cost_channel import ROOT, read, native

FAILED=ROOT/'reports/qa/portable_audit_20261008/runs/20261008_175938_81b17f66/daily_timer'
GOOD=ROOT/'reports/qa/portable_audit_20261008/runs/20261008_175938_81b17f66/daily_legacy_clock'

class DealCoverageTests(unittest.TestCase):
    def test_actual_missing_terminal_deals(self):
        a=deal_coverage(native(FAILED/'report.htm')[2],read(FAILED/'cost.csv',';'))
        self.assertFalse(a['passed']);self.assertEqual(a['missing_deals'],['14','15'])
        self.assertEqual(a['extra_deals'],[]);self.assertEqual(a['duplicate_deals'],[])
    def test_actual_complete_run(self):
        self.assertTrue(deal_coverage(native(GOOD/'report.htm')[2],read(GOOD/'cost.csv',';'))['passed'])
    def test_duplicates_never_mask_missing(self):
        self.assertFalse(deal_coverage([{'deal':'2'},{'deal':'3'}],[{'deal':'2'},{'deal':'2'}])['passed'])
    def test_extra_deals_rejected(self):
        self.assertFalse(deal_coverage([{'deal':'2'}],[{'deal':'2'},{'deal':'3'}])['passed'])

if __name__=='__main__':unittest.main()
