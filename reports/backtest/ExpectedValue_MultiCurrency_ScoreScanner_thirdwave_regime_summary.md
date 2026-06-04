# Regime-Aware ThirdWave Summary

## Scope

- Added a separate `DowFractal_ThirdWave_Regime` branch.
- Existing Phase 2 score scanner and original ThirdWave branch are preserved.
- No `InpRewardR`, timeframe, spread, risk, SL, TP, or parameter optimization changes were made.
- Regime mode allows long entries only in `REGIME_TREND_UP` and short entries only in `REGIME_TREND_DOWN`.
- RANGE / TRANSITION / EXHAUSTION / UNKNOWN are blocked by regime summary counters rather than full per-scan detail rows.

## Run Results

| period | scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | long_net_profit | short_net_profit | xauusd_trade_share_pct | xauusd_net_profit | fx_net_profit | top_structure_stage_fail_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | ThirdWave_original_BOTH | 355 | -914.04 | 0.911 | -2.57 | 15.97 | -501.32 | -412.72 | 74.65 | -1000.83 | 86.79 | no_higher_tf_trend |
| 2024 | ThirdWave_regime_BOTH | 159 | 832.41 | 1.183 | 5.24 | 4.53 | 670.03 | 162.38 | 74.84 | 603.25 | 229.16 | regime_requires_trend_down |
| 2024 | ThirdWave_regime_LONG_ONLY | 100 | 595.83 | 1.213 | 5.96 | 4.98 | 595.83 | 0 | 79.0 | 533.08 | 62.75 | regime_requires_trend_up |
| 2024 | ThirdWave_regime_SHORT_ONLY | 65 | 257.93 | 1.143 | 3.97 | 3.82 | 0 | 257.93 | 64.62 | 46.28 | 211.65 | regime_requires_trend_down |
| 2025 | ThirdWave_original_BOTH | 451 | -464.41 | 0.963 | -1.03 | 17.62 | -1051.26 | 586.85 | 79.16 | -401.84 | -62.57 | no_higher_tf_trend |
| 2025 | ThirdWave_regime_BOTH | 247 | -567.02 | 0.92 | -2.3 | 11.74 | -776.56 | 209.54 | 77.73 | -85.02 | -482.0 | regime_requires_trend_down |
| 2025 | ThirdWave_regime_LONG_ONLY | 156 | -660.2 | 0.854 | -4.23 | 11.71 | -660.2 | 0 | 83.33 | -368.33 | -291.87 | regime_requires_trend_up |
| 2025 | ThirdWave_regime_SHORT_ONLY | 104 | -75.55 | 0.975 | -0.73 | 6.95 | 0 | -75.55 | 67.31 | 234.51 | -310.06 | regime_requires_trend_down |
| 2026YTD | ThirdWave_original_BOTH | 189 | 856.11 | 1.169 | 4.53 | 6.89 | 128.51 | 727.6 | 91.01 | 952.55 | -96.44 | no_higher_tf_trend |
| 2026YTD | ThirdWave_regime_BOTH | 88 | 809.15 | 1.354 | 9.19 | 2.19 | 104.0 | 705.15 | 90.91 | 830.42 | -21.27 | regime_requires_trend_down |
| 2026YTD | ThirdWave_regime_LONG_ONLY | 37 | 116.2 | 1.115 | 3.14 | 3.13 | 116.2 | 0 | 97.3 | 165.97 | -49.77 | regime_requires_trend_up |
| 2026YTD | ThirdWave_regime_SHORT_ONLY | 52 | 674.93 | 1.524 | 12.98 | 1.93 | 0 | 674.93 | 84.62 | 696.07 | -21.14 | regime_requires_trend_down |

## 2025 Regime Evaluation Mix

| scenario | regime | rows | share_pct |
| --- | --- | --- | --- |
| ThirdWave_regime_BOTH | REGIME_TREND_UP | 176254 | 17.09 |
| ThirdWave_regime_BOTH | REGIME_TREND_DOWN | 130912 | 12.7 |
| ThirdWave_regime_BOTH | REGIME_RANGE | 86598 | 8.4 |
| ThirdWave_regime_BOTH | REGIME_TRANSITION | 606696 | 58.84 |
| ThirdWave_regime_BOTH | REGIME_EXHAUSTION | 30612 | 2.97 |
| ThirdWave_regime_LONG_ONLY | REGIME_TREND_UP | 88127 | 17.09 |
| ThirdWave_regime_LONG_ONLY | REGIME_TREND_DOWN | 65456 | 12.7 |
| ThirdWave_regime_LONG_ONLY | REGIME_RANGE | 43299 | 8.4 |
| ThirdWave_regime_LONG_ONLY | REGIME_TRANSITION | 303348 | 58.84 |
| ThirdWave_regime_LONG_ONLY | REGIME_EXHAUSTION | 15306 | 2.97 |
| ThirdWave_regime_SHORT_ONLY | REGIME_TREND_UP | 88127 | 17.09 |
| ThirdWave_regime_SHORT_ONLY | REGIME_TREND_DOWN | 65456 | 12.7 |
| ThirdWave_regime_SHORT_ONLY | REGIME_RANGE | 43299 | 8.4 |
| ThirdWave_regime_SHORT_ONLY | REGIME_TRANSITION | 303348 | 58.84 |
| ThirdWave_regime_SHORT_ONLY | REGIME_EXHAUSTION | 15306 | 2.97 |

## Initial Judgment

- 2024 improved from original BOTH PF `0.911` / DD `15.97%` to regime BOTH PF `1.183` / DD `4.53%`.
- 2025 did not improve expectancy: original BOTH net `-464.41` / PF `0.963` versus regime BOTH net `-567.02` / PF `0.92`. DD improved, but edge did not.
- 2026YTD improved from original BOTH PF `1.169` / DD `6.89%` to regime BOTH PF `1.354` / DD `2.19%`.
- LONG/SHORT asymmetry is not solved in 2025: regime LONG_ONLY remains negative, while regime SHORT_ONLY is close to flat but still negative.
- XAUUSD dependency remains high because regime BOTH still takes roughly 75%-91% of trades in XAUUSD across the tested periods.
- FX expectancy is not stable: regime BOTH FX net is positive in 2024, negative in 2025, and near flat-negative in 2026YTD.
- The next fix should prioritize regime precision and lower-reversal quality before changing reward, spread, timeframe, or SL/TP parameters.

## Artifacts

- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_run_comparison.csv`
- Trade join: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_trade_join.csv`
- By regime: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_by_regime.csv`
- By block reason: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_by_block_reason.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_compile.txt`
