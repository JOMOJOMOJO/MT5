import csv,shutil,tempfile,unittest
from pathlib import Path
from analyze_portable_audit import portfolio_compare
from analyze_cost_channel import ROOT,read

FIXTURE=ROOT/'reports/qa/cost_channel_20261008_r2/runs/20261008_171544_bbf5d27f/daily_smoke'

class PortfolioParityTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.run=Path(self.tmp.name)
        for name in ['report.htm','cost.csv']:shutil.copyfile(FIXTURE/name,self.run/name)
    def tearDown(self):self.tmp.cleanup()
    def mutate(self,fn):
        rows=read(self.run/'cost.csv',';');fn(rows)
        with (self.run/'cost.csv').open('w',encoding='utf-8',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]),delimiter=';');w.writeheader();w.writerows(rows)
    def test_overlapping_symbols_supported(self):
        a=portfolio_compare(FIXTURE,self.run);self.assertTrue(a['passed']);self.assertEqual(a['candidate_trades'],7)
    def test_fill_change_rejected(self):
        self.mutate(lambda rows:rows[0].update(price=str(float(rows[0]['price'])+0.0001)))
        self.assertFalse(portfolio_compare(FIXTURE,self.run)['passed'])
    def test_cost_change_rejected(self):
        self.mutate(lambda rows:rows[-1].update(swap=str(float(rows[-1]['swap'])-1)))
        self.assertFalse(portfolio_compare(FIXTURE,self.run)['passed'])
    def test_missing_exit_rejected(self):
        self.mutate(lambda rows:rows.pop())
        with self.assertRaises(AssertionError):portfolio_compare(FIXTURE,self.run)
    def test_ticket_number_is_not_strategy(self):
        def renumber(rows):
            for r in rows:
                for k in ['deal','position_id','order']:r[k]=str(int(r[k])+10000)
        self.mutate(renumber)
        self.assertTrue(portfolio_compare(FIXTURE,self.run)['passed'])

if __name__=='__main__':unittest.main()
