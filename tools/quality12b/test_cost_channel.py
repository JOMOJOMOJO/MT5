import unittest
from analyze_cost_channel import components,pair,metrics,audit_retry_events,read

def deal(i,pos,kind,side,price,bid,ask,sl=98,volume=1,profit=0,stamp=1000):
    return dict(deal=str(i),position_id=str(pos),symbol='TEST',entry_kind=str(kind),type=str(side),
        price=str(price),bid=str(bid),ask=str(ask),sl=str(sl),tp='0',volume=str(volume),profit=str(profit),
        commission='0',swap='0',fee='0',time_msc=str(stamp),quote_msc=str(stamp),quote_status='CURRENT_EXACT_MSC')

class CostTests(unittest.TestCase):
    def test_long_flat_mid_loses_spread(self):
        c=components(1,101,99,99,101,99,101,2)
        self.assertEqual(c['mid_move_r'],0);self.assertEqual(c['fill_price_r'],-1)
        self.assertEqual(c['spread_cost_r'],1)
    def test_short_flat_mid_loses_spread(self):
        c=components(-1,99,101,99,101,99,101,2)
        self.assertEqual(c['fill_price_r'],-1);self.assertEqual(c['execution_residual_cost_r'],0)
    def test_short_falling_ask_profit(self):
        c=components(-1,100,97,100,101,96,97,2)
        self.assertEqual(c['mid_move_r'],2);self.assertEqual(c['fill_price_r'],1.5)
    def test_adverse_and_favorable_execution(self):
        c=components(1,102,103,99,101,104,106,2)
        self.assertEqual(c['execution_residual_cost_r'],1)
        c=components(-1,101,103,99,101,104,106,2)
        self.assertEqual(c['execution_residual_cost_r'],-2.5)
    def test_overlapping_positions_pair_by_id(self):
        r=[deal(1,1,0,0,100,99,100),deal(2,2,0,1,104,104,105,106),
           deal(3,1,1,1,102,102,103,profit=20,stamp=2000),deal(4,2,1,0,102,101,102,profit=20,stamp=3000)]
        t=pair(r);self.assertEqual(len(t),2);self.assertEqual(metrics(t)['net'],40)
        self.assertTrue(all(x['quote_complete'] for x in t))
    def test_missing_quote_retained(self):
        e=deal(1,1,0,0,100,99,100);x=deal(2,1,1,1,98,98,99,profit=-20,stamp=2000)
        x['quote_status']='MISSING';x['bid']='0';x['ask']='0';x['quote_msc']='0'
        t=pair([e,x]);self.assertEqual(len(t),1);self.assertEqual(t[0]['mid_move_r'],'')
        self.assertEqual(metrics(t)['exact_quote_n'],0);self.assertEqual(metrics(t)['net'],-20)
    def test_cash_identity_includes_fees(self):
        e=deal(1,1,0,0,100,99,100);x=deal(2,1,1,1,102,102,103,profit=20,stamp=2000)
        e['commission']='-2';x['swap']='-3';x['fee']='-1'
        t=pair([e,x])[0];self.assertAlmostEqual(t['net_reconstructed_usd'],14)
    def test_volume_mismatch_fails(self):
        with self.assertRaises(AssertionError):pair([deal(1,1,0,0,100,99,100),deal(2,1,1,1,99,99,100,volume=.5)])
    def test_future_quote_not_usable(self):
        e=deal(1,1,0,0,100,99,100);x=deal(2,1,1,1,102,102,103,profit=20)
        x['quote_msc']='1001';self.assertFalse(pair([e,x])[0]['quote_complete'])
    def test_open_position_fails(self):
        with self.assertRaises(AssertionError):pair([deal(1,1,0,0,100,99,100)])

class RetryAuditTests(unittest.TestCase):
    def row(self,event,retcode='0',bar='2023.01.09 00:00:00'):
        return dict(symbol='AUDUSD',signal_bar=bar,time='2023.01.10 00:01:00',event=event,retcode=retcode)
    def test_rejection_then_resume_is_accounted(self):
        rows=[self.row('SEND_FAILED','10018'),self.row('RETRY_MARKET_CLOSED','10018'),self.row('RETRY_RESUMED'),self.row('SEND_RESULT','10009')]
        self.assertEqual(audit_retry_events(rows)['rejected'],1)
    def test_expired_is_retained(self):
        rows=[self.row('SEND_FAILED','10018'),self.row('RETRY_MARKET_CLOSED','10018'),self.row('RETRY_EXPIRED')]
        self.assertEqual(audit_retry_events(rows)['resolved']['RETRY_EXPIRED'],1)
    def test_old_silent_loss_is_rejected(self):
        with self.assertRaises(AssertionError):audit_retry_events([self.row('SEND_FAILED','10018')])
    def test_ambiguous_send_not_retried(self):
        with self.assertRaises(AssertionError):audit_retry_events([self.row('SEND_FAILED','10012'),self.row('RETRY_MARKET_CLOSED','10018')])
    def test_future_bar_fails(self):
        with self.assertRaises(AssertionError):audit_retry_events([self.row('SIGNAL',bar='2023.01.11 00:00:00')])
    def test_actual_failed_smoke_is_caught(self):
        from pathlib import Path
        p=Path(__file__).resolve().parents[2]/'reports/qa/cost_channel_20261008/runs/20261008_103353_57f61562/daily_smoke/telemetry.csv'
        if not p.exists():self.skipTest('Local historical fixture unavailable')
        with self.assertRaises(AssertionError):audit_retry_events(read(p,';'))

if __name__=='__main__':unittest.main()
