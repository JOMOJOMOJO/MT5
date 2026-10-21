import copy,unittest
from analyze_cost_channel import ROOT,read
from analyze_risk_adjustment import audit_adjustments,entry_plan_coverage,attributable_difference
from portable_risk_audit import minute_key

RUN=ROOT/'reports/qa/portable_audit_20261012_r5/runs/20261012_120220_f6be2b8d/m5_USDJPY_portable'


def fixture(row,enabled=False):
    a={k:row[k] for k in ['time','symbol','side','entry','sl','budget','margin','min_volume','step','max_volume']}
    a.update(enabled=str(int(enabled)),before_reason=row['reason'],before_volume=row['volume'],before_loss=row['planned_loss'],
             checks='0',after_reason=row['reason'],after_volume=row['volume'],after_loss=row['planned_loss'])
    return a


class AdjustmentAuditTests(unittest.TestCase):
    def setUp(self):
        self.risk=read(RUN/'risk.csv',';');self.deals=read(RUN/'cost.csv',';')
        self.row=copy.deepcopy(next(r for r in self.risk if r['reason']=='NORMALIZED_VOLUME_EXCEEDS_RISK'))
        self.a=fixture(self.row,True)
        self.row.update(reason='OK',volume='0.51',planned_loss='64.45')
        self.a.update(checks='1',after_reason='OK',after_volume='0.51',after_loss='64.45')

    def test_actual_legacy_entry_plans(self):entry_plan_coverage(self.deals,self.risk)
    def test_off_fixture_unchanged(self):
        self.assertEqual(audit_adjustments([fixture(r) for r in self.risk],self.risk,False),[])
    def test_smaller_safe_volume_accepted(self):
        self.assertEqual(len(audit_adjustments([self.a],[self.row],True)),1)
    def test_volume_increase_rejected(self):
        self.a['after_volume']=self.row['volume']='0.53'
        with self.assertRaises(AssertionError):audit_adjustments([self.a],[self.row],True)
    def test_budget_breach_rejected(self):
        self.a['after_loss']=self.row['planned_loss']='70'
        with self.assertRaises(AssertionError):audit_adjustments([self.a],[self.row],True)
    def test_other_reason_cannot_trigger_repair(self):
        self.a['before_reason']='INSUFFICIENT_MARGIN'
        with self.assertRaises(AssertionError):audit_adjustments([self.a],[self.row],True)
    def test_off_cannot_change(self):
        self.a['enabled']='0'
        with self.assertRaises(AssertionError):audit_adjustments([self.a],[self.row],False)
    def test_missing_entry_plan_rejected(self):
        with self.assertRaises(AssertionError):entry_plan_coverage(self.deals,[])
    def test_trade_changes_without_recovery_rejected(self):
        mutated=copy.deepcopy(self.deals);mutated[0]['volume']='9'
        with self.assertRaises(AssertionError):attributable_difference(self.deals,mutated,[])
    def test_unchanged_trade_sequence(self):
        self.assertEqual(attributable_difference(self.deals,self.deals,[])['classification'],'NO_EXECUTION_CHANGE')
    def test_changes_before_recovered_entry_rejected(self):
        mutated=copy.deepcopy(self.deals);mutated[0]['volume']='9'
        entry=next(d for d in self.deals if d['entry_kind']=='0' and d!=self.deals[0])
        r=dict(symbol=entry['symbol'],time=next(r['time'] for r in self.risk if minute_key(r['time'])==int(entry['time_msc'])//60000))
        with self.assertRaises(AssertionError):attributable_difference(self.deals,mutated,[r])


if __name__=='__main__':unittest.main()
