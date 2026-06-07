# Nested N-Wave Neckline Break Short-Period Validation

## Scope

- Added `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK` as a separate research mode.
- Existing score scanner, Phase2, ThirdWave, v2, v3, and v4 branches were left intact.
- Nested branch uses H4/H1/M15 via presets, fixed `InpRewardR=2.0`, no optimization.
- Short-period windows only: 2025-02, 2025-08, 2025-10, 2026-Q1.

## Comparison

| period | scenario | trades | profit_factor | expected_payoff | net_profit | max_balance_dd_pct | fx_net | xauusd_net | long_net | short_net | best_label | worst_label |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025-02 | current_ThirdWave_regime_BOTH_all_5m | 16 | 2.293 | 23.36 | 373.68 | 0.99 | 102.97 | 270.71 | 237.09 | 136.59 | unclear:373.68 |  |
| 2025-02 | v4_early_reversal_BOTH_all_5m | 27 | 1.422 | 10.3 | 278.18 | 1.95 | 199.98 | 78.2 | -26.73 | 304.91 | early_higher_low:253.21; candle_reversal:107.65; micro_break:37.92 | early_lower_high:-75.92; momentum_turn:-44.68 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 12 | 0.626 | -13.91 | -166.94 | 2.07 | -304.5 | 137.56 | -163.64 | -3.3 | neckline_break_initial:52.25 | neckline_break_late:-168.37; clean_nested_nwave_entry:-50.82 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 13 | 0.84 | -5.49 | -71.42 | 2.07 | -208.98 | 137.56 | -163.64 | 92.22 | neckline_break_initial:52.25 | neckline_break_late:-72.85; clean_nested_nwave_entry:-50.82 |
| 2025-08 | current_ThirdWave_regime_BOTH_all_5m | 13 | 0.899 | -3.09 | -40.11 | 2.45 | 76.22 | -116.33 | -70.61 | 30.5 |  | unclear:-40.11 |
| 2025-08 | v4_early_reversal_BOTH_all_5m | 33 | 1.215 | 5.94 | 195.88 | 3.67 | -126.92 | 322.8 | 276.69 | -80.81 | candle_reversal:183.69; early_lower_high:50.16; micro_break:48.79 | early_higher_low:-86.76 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 2 | 1.514 | 13.57 | 27.14 | 0.52 | -52.77 | 79.91 | 79.91 | -52.77 | neckline_break_late:27.14 |  |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 2 | 1.514 | 13.57 | 27.14 | 0.52 | -52.77 | 79.91 | 79.91 | -52.77 | neckline_break_late:27.14 |  |
| 2025-10 | current_ThirdWave_regime_BOTH_all_5m | 20 | 1.823 | 17.26 | 345.18 | 1.75 | 52.5 | 292.68 | 236.4 | 108.78 | unclear:345.18 |  |
| 2025-10 | v4_early_reversal_BOTH_all_5m | 38 | 1.077 | 2.09 | 79.24 | 2.48 | -14.86 | 94.1 | 222.62 | -143.38 | micro_break:141.86; early_higher_low:78.16 | candle_reversal:-123.14; early_lower_high:-17.64 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 4 | 5.306 | 53.17 | 212.7 | 0.49 | 98.56 | 114.14 | 163.54 | 49.16 | neckline_break_initial:114.14; neckline_break_late:98.56 |  |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 5 | 7.348 | 62.71 | 313.57 | 0.49 | 199.43 | 114.14 | 163.54 | 150.03 | neckline_break_late:199.43; neckline_break_initial:114.14 |  |
| 2026-Q1 | current_ThirdWave_regime_BOTH_all_5m | 60 | 1.402 | 10.17 | 610.21 | 2.65 | 9.64 | 600.57 | 87.84 | 522.37 | unclear:610.21 |  |
| 2026-Q1 | v4_early_reversal_BOTH_all_5m | 96 | 1.397 | 10.91 | 1047.07 | 4.72 | 86.96 | 960.11 | -169.9 | 1216.97 | candle_reversal:736.90; micro_break:340.88; early_lower_high:274.84 | early_higher_low:-289.18; confirmed_fractal_reclaim:-16.37 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 25 | 0.251 | -30.52 | -763.08 | 8.15 | -520.06 | -243.02 | -515.34 | -247.74 |  | neckline_break_late:-294.89; neckline_break_initial:-243.67; clean_nested_nwave_entry:-130.75 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 27 | 0.33 | -26.54 | -716.68 | 7.69 | -473.66 | -243.02 | -516.66 | -200.02 |  | neckline_break_late:-248.49; neckline_break_initial:-243.67; clean_nested_nwave_entry:-130.75 |

## Short-Period Gate

- gate_pass: `false`
- reason: Nested short-period gate failed: performance was period-specific and broke badly in at least one validation window.
- details: C: period_passes=0/4 severe_fails=2; D: period_passes=0/4 severe_fails=1

Annual BT was not run unless this gate passed.

## Artifacts

- Comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_comparison.csv`
- By symbol: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_by_symbol.csv`
- By direction: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_by_direction.csv`
- By label: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_by_label.csv`
- By fib zone: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_by_fib_zone.csv`
- FX vs XAUUSD: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_fx_vs_xauusd.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_compile.log`
