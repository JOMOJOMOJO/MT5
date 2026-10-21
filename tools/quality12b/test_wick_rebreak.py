"""Reject leaked/malformed cohorts and keep non-events out of P&L statistics."""
import copy,unittest
from analyze_wick_rebreak import check_cohort,ms,shadow_metrics


def fixture():
    c=[dict(id='x',signal_bar='2023.01.02 08:00:00',available_at='2023.01.02 08:05:00',high='101',anchor_low='99',
            anchor_bar='2023.01.02 07:50:00',anchor_confirmed='2023.01.02 08:00:00',high_bar='2023.01.02 07:45:00',high_confirmed='2023.01.02 07:55:00')]
    event=[dict(id='x',event='B_TRIGGER',time_msc=str(ms('2023.01.02 08:10:00')),closed_bar='2023.01.02 08:05:00',closed_price='102',fixed_high='101',anchor_low='99',age_bars='1')]
    entries=[];outcomes=[];contexts=[]
    for arm,when,price in [('A','2023.01.02 08:05:00',100),('B','2023.01.02 08:10:00',102.1)]:
        entries.append(dict(id='x',arm=arm,time_msc=str(ms(when)),ask=str(price),sl=str(price-2),tp=str(price+3),risk='2'))
        outcomes.append(dict(id='x',arm=arm,entry_msc=str(ms(when)),exit_msc=str(ms('2023.01.02 09:40:00')),entry=str(price),sl=str(price-2),tp=str(price+3),
            exit_price=str(price+1),result_r='.5',mfe_r='.5',mae_r='.1',outcome='TIME_EXIT',ambiguous_exit_minute='0',exit_minute_complete='1'))
        for tf in ['PERIOD_M15','PERIOD_H1','PERIOD_H4']:
            contexts.append(dict(id='x',arm=arm,tf=tf,decision=when,asof='2023.01.02 07:00:00',break_confirmed='2023.01.02 06:00:00'))
    bars=[dict(bar_time='2023.01.02 08:00:00',available_at='2023.01.02 08:05:00',observed_msc=str(ms('2023.01.02 08:05:00')),high='101',close='100'),
          dict(bar_time='2023.01.02 08:05:00',available_at='2023.01.02 08:10:00',observed_msc=str(ms('2023.01.02 08:10:00')),high='103',close='102')]
    return [c,event,entries,outcomes,bars,contexts]


class AuditTests(unittest.TestCase):
    def test_valid(self):self.assertEqual(check_cohort(*fixture())['b_triggers'],1)
    def reject(self,index,change):
        rows=fixture();change(rows[index])
        with self.assertRaises(AssertionError):check_cohort(*rows)
    def test_future_pivot(self):self.reject(0,lambda r:r[0].update(anchor_confirmed='2023.01.02 08:06:00'))
    def test_duplicate_candidate(self):self.reject(0,lambda r:r.append(copy.deepcopy(r[0])))
    def test_not_strict_break(self):self.reject(1,lambda r:r[0].update(closed_price='101'))
    def test_future_closed_bar(self):self.reject(1,lambda r:r[0].update(closed_bar='2023.01.02 08:10:00'))
    def test_late_trigger(self):self.reject(1,lambda r:r[0].update(age_bars='19'))
    def test_missing_shadow(self):self.reject(3,lambda r:r.pop())
    def test_fake_result(self):self.reject(3,lambda r:r[0].update(result_r='1.5'))
    def test_context_future(self):self.reject(5,lambda r:r[0].update(asof='2024.01.01 00:00:00'))
    def test_backdated_entry(self):self.reject(2,lambda r:r[1].update(time_msc=str(ms('2023.01.02 08:09:00'))))
    def test_ambiguous_excluded(self):
        r=fixture()[3];r[0]['ambiguous_exit_minute']='1';self.assertEqual(shadow_metrics(r)['n_evaluable'],1)
    def test_censored_not_zero_loss(self):
        r=fixture()[3];r[0]['outcome']='END_CENSORED';self.assertEqual(shadow_metrics(r)['expectancy_r'],.5)
    def test_incomplete_exit_minute(self):
        r=fixture()[3]
        for x in r:x['exit_minute_complete']='0'
        self.assertIsNone(shadow_metrics(r)['expectancy_r'])


if __name__=='__main__':unittest.main()
