"""Meaningful regressions: reject a correct-looking fingerprint of the wrong year."""
import copy
import unittest
from analyze_wick_rebreak_r2 import history_coverage, epoch, TFS
from prepare_wick_rebreak_r2 import revised_observer
from prepare_portable_audit import ROOT


def fixture(year=2025,end=None):
    spec=dict(symbol='USDJPY',date_from=f'{year}.01.01',date_to=end or f'{year+1}.01.01')
    start=epoch(spec['date_from']);finish=epoch(spec['date_to'])-61
    nmonths=9 if end and end.endswith('.10.01') else 12
    row=dict(symbol='USDJPY',tf='',**{'from':str(epoch(f'{year-1}.01.01'))},to=str(finish),
             first=str(epoch(f'{year-1}.01.02')),last=str(finish-86400),count='500',fingerprint='123',
             test_start=str(start),test_end=str(finish),test_count='250',test_first=str(start+86400),
             test_last=str(finish-86400),test_months=','.join(f'{year}{m:02}' for m in range(1,nmonths+1)))
    return [dict(row,tf=tf) for tf in TFS],spec,{start},{finish}


class PeriodCoverageTests(unittest.TestCase):
    def test_current_year(self):self.assertTrue(history_coverage(*fixture())['passed'])
    def test_partial_2026(self):self.assertTrue(history_coverage(*fixture(2026,'2026.10.01'))['passed'])
    def reject(self,change):
        args=fixture();change(args)
        self.assertFalse(history_coverage(*args)['passed'])
    def test_empty_history(self):self.reject(lambda x:x[0].clear())
    def test_old_schema(self):self.reject(lambda x:x[0][0].pop('test_start'))
    def test_wrong_year(self):self.reject(lambda x:x[0][0].update(test_start=str(epoch('2023.01.01'))))
    def test_missing_month(self):self.reject(lambda x:x[0][0].update(test_months=x[0][0]['test_months'].replace('202506,','')))
    def test_truncated_end(self):self.reject(lambda x:x[0][0].update(test_last=str(epoch('2025.03.31'))))
    def test_truncated_start(self):self.reject(lambda x:x[0][0].update(test_first=str(epoch('2025.02.01'))))
    def test_future_history(self):self.reject(lambda x:x[0][0].update(last=str(epoch('2026.01.02'))))
    def test_duplicate_tf(self):self.reject(lambda x:x[0].append(copy.deepcopy(x[0][0])))
    def test_missing_warmup(self):self.reject(lambda x:x[0][0].update(first=str(epoch('2025.01.01'))))
    def test_source_observer_only(self):
        old=(ROOT/'mql/Include/Research/PortableEnvironmentAuditV2.mqh').read_text(encoding='utf-8')
        new=revised_observer(old)
        for name in ['reference','wick_rebreak']:
            source=(ROOT/f'reports/qa/wick_rebreak_20261013/frozen/{name}.mq5').read_text(encoding='utf-8')
            self.assertEqual(source.count(old),1)
            updated=source.replace(old,new)
            self.assertEqual(source[len(old):],updated[len(new):])


if __name__=='__main__':unittest.main()
