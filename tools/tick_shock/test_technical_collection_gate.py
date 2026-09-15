"""The legacy exception must not hide tick or Technical tracking data loss."""
import unittest
from verify_technical_month_capture import technical_integrity

def fixture():
    rows=[dict(record_type='INTEGRITY',value='validation=VALIDATION_INVALID;event_pool_exhaustions=40;pending_capacity_hits=0;dropped_ticks=0;cursor_stalls=0;incomplete_frontier=false;root_cause='),
          dict(record_type='STATISTICAL_CLUSTER',value='track_capacity_hits=0'),
          dict(record_type='MATCHED_CONTROL',value='capacity_hits=0;drops=0')]
    rows += [dict(record_type='SYMBOL',value='read_through_msc=100;requested_to_msc=100;history_synchronized=true;root_cause=;cursor_stalls=0;page_limits=0;last_copy_error=0') for _ in range(6)]
    return rows

class GateTests(unittest.TestCase):
    def test_legacy_pool_only(self):
        checks,legacy=technical_integrity(fixture())
        self.assertTrue(all(checks.values()))
        self.assertEqual(legacy['validation'],'VALIDATION_INVALID')
    def test_losses_remain_blocking(self):
        for old,new in [('dropped_ticks=0','dropped_ticks=1'),('pending_capacity_hits=0','pending_capacity_hits=1'),('cursor_stalls=0','cursor_stalls=1'),('incomplete_frontier=false','incomplete_frontier=true')]:
            with self.subTest(new=new):
                rows=fixture();rows[0]['value']=rows[0]['value'].replace(old,new)
                self.assertFalse(all(technical_integrity(rows)[0].values()))
    def test_tracking_loss(self):
        rows=fixture();rows[1]['value']='track_capacity_hits=1'
        self.assertFalse(all(technical_integrity(rows)[0].values()))
    def test_incomplete_readthrough(self):
        rows=fixture();rows[3]['value']=rows[3]['value'].replace('read_through_msc=100','read_through_msc=99')
        self.assertFalse(all(technical_integrity(rows)[0].values()))
    def test_missing_summary(self):
        self.assertFalse(all(technical_integrity([])[0].values()))
    def test_unexplained_invalid(self):
        rows=fixture();rows[0]['value']=rows[0]['value'].replace('event_pool_exhaustions=40','event_pool_exhaustions=0')
        self.assertFalse(all(technical_integrity(rows)[0].values()))

if __name__=='__main__':unittest.main()
