# Session Reversal Dow-Fractal H1/M30/M5 Cycles

## Scope

- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Main concept: Dow theory and fractal structure, not a loose "fractal-like" label.
- Final structure: H1 top context trend/range, M30 ordered Dow wave3 or trend-bias structure, M5 first-pullback/retest entry.
- Backtest model: MT5 Model=4, M15 tester period, 2025 shallow/full checks, deposit 10000 USD.

## Implementation Notes

- Confirmed pivots are collected with left/right `InpSwingDepth` bars and ATR minimum swing filtering.
- Top context can be treated as trend/range only with `InpTopContextTrendOnly=true`.
- Structure direction uses ordered Dow wave3 by default. `InpAllowStructureTrendBiasWhenNoWave3=true` allows M30 Dow trend bias only when a confirmed wave3 is not available.
- Neckline setups require the retest candle to close back beyond the neckline with `InpRequireRetestCloseBeyondNeckline=true`.
- The final cycle requires the previous closed bar to break the neckline before the current bar can be treated as the first retest. This is closer to "do not jump in at the turn; enter after confirmation on the first pullback."
- The compile log at `compile_metaeditor.log` reports `0 errors, 0 warnings`.

## Results

| cycle | period | trades | net | PF | avg_R | closed-trade max DD | note |
|---|---:|---:|---:|---:|---:|---:|---|
| c1_full_hard_wave3 | 2025 full year | 163 | -272.88 | 0.844 | -0.0686 | 451.15 | Ordered H1/M30/M5 hard structure wave3 |
| c2_q1_soft_bias | 2025 Q1 | 101 | -74.66 | 0.935 | -0.0319 | 346.97 | Allow M30 trend bias when no wave3 |
| c3_q1_retest_reclaim | 2025 Q1 | 99 | -25.59 | 0.977 | -0.0128 | 261.77 | Require retest close beyond neckline |
| c4_q1_be_1_1r | 2025 Q1 | 99 | -93.88 | 0.914 | -0.0426 | 295.79 | Break-even at 1.1R |
| c5_q1_break_then_retest | 2025 Q1 | 98 | -61.21 | 0.942 | -0.0264 | 262.09 | Previous bar break, current bar retest |
| c6_full_cycle5_final | 2025 full year | 285 | -700.13 | 0.788 | -0.1046 | 831.72 | Final concept-correct full-year check |

## Diagnosis

- Trade count was restored in the final full-year run: 285 trades in 2025.
- The strategy still fails expectancy: PF 0.788 and avg_R -0.1046 in the final 2025 run.
- The main structural loss is `neckline_retest_failed`: 147 trades / -2887.89 in c6.
- Full SL remains too frequent: 127 full SL exits in c6, a 44.56% full-SL rate.
- Break-even at 1.1R did not help in c4. It triggered 22 times, created 4 break-even exits, did not reduce full SL, and reduced PF from 0.977 to 0.914 versus c3.
- London was positive in c6, but London/NewYork overlap was strongly negative. This is not enough to promote London-only logic because the current objective forbids repairing by narrow time filtering.
- USDJPY carried much of the earlier strength, but the final full-year basket still lost money. This is not a valid basis for symbol exclusion.
- Both directions were negative in c6, so direction filtering is not an acceptable repair.

## Gate Decision

No operating candidate.

The final version clears the 200-trade count threshold, but fails PF, avg_R, net, and drawdown quality. It should not move to 3-year fixed BT or OOS. The next useful research step is not narrower parameter tuning; it is to redesign the retest validation so failed neckline retests are filtered before entry without overfitting by symbol, direction, weekday, or a single session.

