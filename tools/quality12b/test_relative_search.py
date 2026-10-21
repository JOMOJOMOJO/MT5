import copy
from pathlib import Path
import unittest
from analyze_relative_search import months, rank_training, stats

ROOT=Path(__file__).resolve().parents[2]

class RelativeStudyTests(unittest.TestCase):
    def test_ranking_cannot_use_validation_outcomes(self):
        rows=[dict(stage='Search',cell='a',train_eligible=True,worst_annual_mean_price_r=.1,net=10),
              dict(stage='Search',cell='b',train_eligible=False,worst_annual_mean_price_r=.5,net=100),
              dict(stage='Validate',cell='b',train_eligible=True,worst_annual_mean_price_r=1e9,net=1e9)]
        before=rank_training(rows)
        changed=copy.deepcopy(rows);changed[-1].update(net=-1e12,worst_annual_mean_price_r=-1e12)
        self.assertEqual(before,rank_training(changed))
        self.assertEqual(before[0]['cell'],'a')

    def test_zero_trade_months_remain_in_denominator(self):
        m=months('2023.01.01','2025.01.01')
        self.assertEqual(len(m),24)
        self.assertEqual(m[-1],'2024-12')
        self.assertEqual(len(months('2025.01.01','2026.10.01')),21)

    def test_cash_costs_and_price_r_are_not_conflated(self):
        s=stats([dict(net='9',implied_initial_r_price='1.5'),dict(net='-10',implied_initial_r_price='-1')])
        self.assertEqual(s['net'],-1);self.assertAlmostEqual(s['pf'],.9)
        self.assertAlmostEqual(s['mean_price_r'],.25)
        self.assertIsNone(stats([])['mean_price_r'])

    def test_no_absolute_price_inputs_or_micro_cap_escalation(self):
        config=(ROOT/'mql/Include/RelativeContinuation/Configuration.mqh').read_text()
        for forbidden in ('Pips','Points','MicroCap','BalanceThreshold'):
            self.assertNotIn(forbidden,config)

    def test_closed_atr_and_position_safety_contract(self):
        risk=(ROOT/'mql/Include/RelativeContinuation/RuntimeRisk.mqh').read_text()
        orders=(ROOT/'mql/Include/RelativeContinuation/Orders.mqh').read_text()
        self.assertIn('CopyBuffer(distanceAtrHandle,0,1,1,value)',risk)
        self.assertIn('OrderCalcProfit(side,runtimeSymbol',risk)
        self.assertIn('MIN_VOLUME_EXCEEDS_RISK',risk)
        self.assertIn('brokerStopDistance',orders)
        self.assertIn('CheckTradeResult(sent,"open")',orders)
        self.assertNotIn('SYMBOL_TRADE_TICK_VALUE',risk)

if __name__=='__main__': unittest.main()
