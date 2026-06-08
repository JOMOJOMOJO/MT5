# Nested N-Wave Retest Confirmation Short-Period Validation

## Scope

- Added `RESEARCH_STRATEGY_NESTED_NWAVE_RETEST_CONFIRMATION` as an independent research mode.
- Existing Nested neckline-break, ThirdWave, v2/v3/v4, Phase2, SL/TP, RewardR, timeframe, spread guard, risk sizing, and CTrade bridge were not changed.
- Retest branch uses one fixed diagnostic rule set: breakout within 8 M15 bars, retest within 0.5 M15 ATR of neckline, no right-side invalidation, then M15 candle re-affirmation or minor rebreak.
- Validation is short-period only: 2025-02, 2025-08, 2025-10, 2026-Q1. No annual BT was run.

## Comparison

| period | scenario | trades | PF | avg_R | net | false break % | reached 1R % | reached 2R % | FX net | XAUUSD net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 13 | 0.84 | -0.08 | -71.42 | 61.54 | 46.15 | 30.77 | -208.98 | 137.56 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 12 | 0.626 | -0.254 | -166.94 | 66.67 | 41.67 | 25.0 | -304.5 | 137.56 |
| 2025-02 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 5 | 0.444 | -0.409 | -110.25 | 60.0 | 20.0 | 20.0 | -198.29 | 88.04 |
| 2025-02 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 5 | 0.444 | -0.409 | -110.25 | 60.0 | 20.0 | 20.0 | -198.29 | 88.04 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 2 | 1.514 | 0.501 | 27.14 | 100.0 | 50.0 | 50.0 | -52.77 | 79.91 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 2 | 1.514 | 0.501 | 27.14 | 100.0 | 50.0 | 50.0 | -52.77 | 79.91 |
| 2025-08 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 1 |  | 2.009 | 79.88 | 100.0 | 100.0 | 100.0 | 0 | 79.88 |
| 2025-08 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 1 |  | 2.009 | 79.88 | 100.0 | 100.0 | 100.0 | 0 | 79.88 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 5 | 7.348 | 1.405 | 313.57 | 40.0 | 100.0 | 80.0 | 199.43 | 114.14 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 4 | 5.306 | 1.25 | 212.7 | 50.0 | 100.0 | 75.0 | 98.56 | 114.14 |
| 2025-10 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 1 |  | 2.0 | 99.6 | 100.0 | 100.0 | 100.0 | 0 | 99.6 |
| 2025-10 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 1 |  | 2.0 | 99.6 | 100.0 | 100.0 | 100.0 | 0 | 99.6 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 27 | 0.33 | -0.564 | -716.68 | 59.26 | 51.85 | 18.52 | -473.66 | -243.02 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 25 | 0.251 | -0.649 | -763.08 | 64.0 | 48.0 | 12.0 | -520.06 | -243.02 |
| 2026-Q1 | Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 17 | 0.457 | -0.481 | -347.97 | 58.82 | 52.94 | 17.65 | -146.16 | -201.81 |
| 2026-Q1 | Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 15 | 0.324 | -0.612 | -401.16 | 66.67 | 53.33 | 13.33 | -199.35 | -201.81 |

## 2026-Q1 Check

| scenario | trades | PF | avg_R | net | false break % | FX net | XAUUSD net | long net | short net |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 27 | 0.33 | -0.564 | -716.68 | 59.26 | -473.66 | -243.02 | -516.66 | -200.02 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 25 | 0.251 | -0.649 | -763.08 | 64.0 | -520.06 | -243.02 | -515.34 | -247.74 |
| Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 17 | 0.457 | -0.481 | -347.97 | 58.82 | -146.16 | -201.81 | -123.55 | -224.42 |
| Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 15 | 0.324 | -0.612 | -401.16 | 66.67 | -199.35 | -201.81 | -123.55 | -277.61 |

## 2025-10 Preservation

| scenario | trades | PF | avg_R | net | false break % | reached 2R % |
|---|---:|---:|---:|---:|---:|---:|
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 5 | 7.348 | 1.405 | 313.57 | 40.0 | 80.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 4 | 5.306 | 1.25 | 212.7 | 50.0 | 75.0 |
| Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 1 |  | 2.0 | 99.6 | 100.0 | 100.0 |
| Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R | 1 |  | 2.0 | 99.6 | 100.0 | 100.0 |

## Judgement

- Retest all-candidates total trades: `24` versus instant all-candidates `47`.
- Retest all-candidates total net: `-278.74` versus instant all-candidates `-447.39`.
- The branch is judged on whether it reduces 2026-Q1 false-break damage without deleting the 2025-10 strength. It is not a RewardR or symbol filter test.
- 2026-Q1 improved versus the best instant Nested branch in net terms.
- 2025-10 strength was not preserved enough: retest confirmation kept less than half of the instant-breakout October trades.
- False-break rate did not materially improve; the better 2026-Q1 net came mostly from fewer trades and smaller FX damage, not from a clean false-break solution.
- Short-period gate did not pass. No annual BT should be run for this branch yet.

## Artifacts

- Comparison CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_comparison.csv`
- Retest quality aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_retest_quality.csv`
- MFE/MAE/R reach: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_retest_mfe_mae.csv`
- Full diagnostics: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_diagnostics.csv`
