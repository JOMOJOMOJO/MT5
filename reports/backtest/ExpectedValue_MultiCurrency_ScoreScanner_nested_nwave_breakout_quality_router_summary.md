# Nested N-Wave Breakout Quality Router Short-Period Validation

## Scope

- Added `RESEARCH_STRATEGY_NESTED_NWAVE_BREAKOUT_QUALITY_ROUTER` as an independent research mode.
- Existing ThirdWave, v2/v3/v4, Phase2, score scanner, instant Nested, and Retest Confirmation behavior were not changed.
- Router rule set is fixed: `strong_breakout` enters immediately, `weak_breakout` waits for retest confirmation, and `dirty_breakout` is skipped.
- Validation used only 2025-02, 2025-08, 2025-10, and 2026-Q1. Annual BT is gated and was not run unless the short-period result passed.

## Comparison

| period | scenario | trades | PF | avg_R | net | false break % | reached 1R % | reached 2R % | FX net | XAUUSD net | long net | short net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | 2 | 2.04 | 0.503 | 49.75 | 50.0 | 50.0 | 50.0 | -47.83 | 97.58 | 0 | 49.75 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | 2 | 2.04 | 0.503 | 49.75 | 50.0 | 50.0 | 50.0 | -47.83 | 97.58 | 0 | 49.75 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 13 | 0.84 | -0.08 | -71.42 | 61.54 | 46.15 | 30.77 | -208.98 | 137.56 | -163.64 | 92.22 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 12 | 0.626 | -0.254 | -166.94 | 66.67 | 41.67 | 25.0 | -304.5 | 137.56 | -163.64 | -3.3 |
| 2025-02 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 5 | 0.444 | -0.409 | -110.25 | 40.0 | 20.0 | 20.0 | -198.29 | 88.04 | 37.22 | -147.47 |
| 2025-02 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 5 | 0.444 | -0.409 | -110.25 | 40.0 | 20.0 | 20.0 | -198.29 | 88.04 | 37.22 | -147.47 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 2 | 1.514 | 0.501 | 27.14 | 100.0 | 50.0 | 50.0 | -52.77 | 79.91 | 79.91 | -52.77 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 2 | 1.514 | 0.501 | 27.14 | 100.0 | 50.0 | 50.0 | -52.77 | 79.91 | 79.91 | -52.77 |
| 2025-08 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 1 |  | 2.009 | 79.88 | 100.0 | 100.0 | 100.0 | 0 | 79.88 | 79.88 | 0 |
| 2025-08 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 1 |  | 2.009 | 79.88 | 100.0 | 100.0 | 100.0 | 0 | 79.88 | 79.88 | 0 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | 1 |  | 2.0 | 93.96 | 100.0 | 100.0 | 100.0 | 0 | 93.96 | 93.96 | 0 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | 1 |  | 2.0 | 93.96 | 100.0 | 100.0 | 100.0 | 0 | 93.96 | 93.96 | 0 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 5 | 7.348 | 1.405 | 313.57 | 40.0 | 100.0 | 80.0 | 199.43 | 114.14 | 163.54 | 150.03 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 4 | 5.306 | 1.25 | 212.7 | 50.0 | 100.0 | 75.0 | 98.56 | 114.14 | 163.54 | 49.16 |
| 2025-10 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 1 |  | 2.0 | 99.6 | 100.0 | 100.0 | 100.0 | 0 | 99.6 | 99.6 | 0 |
| 2025-10 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 1 |  | 2.0 | 99.6 | 100.0 | 100.0 | 100.0 | 0 | 99.6 | 99.6 | 0 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | 6 | 0.4 | -0.505 | -139.9 | 83.33 | 50.0 | 16.67 | -56.38 | -83.52 | -87.02 | -52.88 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | 6 | 0.4 | -0.505 | -139.9 | 83.33 | 50.0 | 16.67 | -56.38 | -83.52 | -87.02 | -52.88 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 27 | 0.33 | -0.564 | -716.68 | 59.26 | 51.85 | 18.52 | -473.66 | -243.02 | -516.66 | -200.02 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 25 | 0.251 | -0.649 | -763.08 | 64.0 | 48.0 | 12.0 | -520.06 | -243.02 | -515.34 | -247.74 |
| 2026-Q1 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 17 | 0.457 | -0.481 | -347.97 | 58.82 | 52.94 | 17.65 | -146.16 | -201.81 | -123.55 | -224.42 |
| 2026-Q1 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 15 | 0.324 | -0.612 | -401.16 | 66.67 | 53.33 | 13.33 | -199.35 | -201.81 | -123.55 | -277.61 |

## Breakout Quality Counts

| period | scenario | quality | rows |
|---|---|---|---:|
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | dirty_breakout | 27 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | strong_breakout | 5 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | unclassified | 668 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | weak_breakout | 11 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | dirty_breakout | 27 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | strong_breakout | 5 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | unclassified | 668 |
| 2025-02 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | weak_breakout | 11 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | not_recorded | 73 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | not_recorded | 72 |
| 2025-02 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | not_recorded | 716 |
| 2025-02 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | not_recorded | 716 |
| 2025-08 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | dirty_breakout | 14 |
| 2025-08 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | unclassified | 457 |
| 2025-08 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | weak_breakout | 5 |
| 2025-08 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | dirty_breakout | 14 |
| 2025-08 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | unclassified | 457 |
| 2025-08 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | weak_breakout | 5 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | not_recorded | 22 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | not_recorded | 22 |
| 2025-08 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | not_recorded | 478 |
| 2025-08 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | not_recorded | 478 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | dirty_breakout | 16 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | strong_breakout | 7 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | unclassified | 476 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | weak_breakout | 7 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | dirty_breakout | 16 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | strong_breakout | 7 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | unclassified | 476 |
| 2025-10 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | weak_breakout | 7 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | not_recorded | 39 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | not_recorded | 39 |
| 2025-10 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | not_recorded | 507 |
| 2025-10 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | not_recorded | 507 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | dirty_breakout | 76 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | strong_breakout | 13 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | unclassified | 1781 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | weak_breakout | 36 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | dirty_breakout | 76 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | strong_breakout | 13 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | unclassified | 1781 |
| 2026-Q1 | Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R | weak_breakout | 36 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | not_recorded | 187 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | not_recorded | 186 |
| 2026-Q1 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | not_recorded | 1929 |
| 2026-Q1 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | not_recorded | 1929 |

## Judgement

- Router total net: `7.62`.
- Instant total net: `-1137.57`.
- Retest total net: `-610.67`.
- 2026-Q1 damage improved versus the best instant branch.
- 2025-10 strength was not preserved enough; Router deleted too much October net.
- Short-period gate did not pass. No annual BT was run.

## Artifacts

- Comparison CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_comparison.csv`
- Breakout quality summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_breakout_quality_summary.csv`
- Trade diagnostics: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_breakout_quality_diagnostics.csv`
- Avoided dirty samples: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_avoided_dirty_breakout_samples.csv`
- Missed strong samples: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_missed_strong_breakout_samples.csv`
