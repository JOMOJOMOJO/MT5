# Nested N-Wave Neckline Break Failure Decomposition

## Scope

- Diagnostic-only pass for the existing `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK` short-period runs.
- No EA entry logic, order bridge, SL/TP, RewardR, timeframe, spread guard, risk sizing, or parameters were changed.
- No annual backtests were run.
- MFE/MAE and R-reach diagnostics use MT5 M5 OHLC after the existing entries. Same-bar ambiguity is not promoted to a win.

## Short-Period Context

| period | scenario | trades | PF | expected | net | max DD % | FX net | XAU net |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 12 | 0.626 | -13.91 | -166.94 | 2.07 | -304.5 | 137.56 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 13 | 0.84 | -5.49 | -71.42 | 2.07 | -208.98 | 137.56 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 2 | 1.514 | 13.57 | 27.14 | 0.52 | -52.77 | 79.91 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 2 | 1.514 | 13.57 | 27.14 | 0.52 | -52.77 | 79.91 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 4 | 5.306 | 53.17 | 212.7 | 0.49 | 98.56 | 114.14 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 5 | 7.348 | 62.71 | 313.57 | 0.49 | 199.43 | 114.14 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 25 | 0.251 | -30.52 | -763.08 | 8.15 | -520.06 | -243.02 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 27 | 0.33 | -26.54 | -716.68 | 7.69 | -473.66 | -243.02 |

## 2026-Q1 Failure Summary

| scenario | trades | PF | expected | net | avg MFE R | avg MAE R | false break % | reached 1R % | reached 2R % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 27 | 0.33 | -26.54 | -716.68 | 1.088 | 1.209 | 59.26 | 51.85 | 18.52 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 25 | 0.251 | -30.52 | -763.08 | 1.015 | 1.243 | 64.0 | 48.0 | 12.0 |

Key read:

- 2026-Q1 did not fail because XAUUSD alone broke. FX was also materially negative, especially GBPUSD/USDJPY.
- The main defect is not simply that 2R was too far. Many losers failed before reaching even 0.5R or returned inside the neckline soon after entry.
- `clean_nested_nwave_entry` is not a true clean label yet. It means the coded stages passed, not that the breakout had enough follow-through quality.

## 2026-Q1 Exposure Breakdown

| scenario | group | trades | net | PF | avg MFE R | false break % |
|---|---|---:|---:|---:|---:|---:|
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | symbol=GBPUSD | 9 | -281.63 | 0.262 | 1.113 | 88.89 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | symbol=GBPUSD | 9 | -281.63 | 0.262 | 1.113 | 88.89 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | symbol=XAUUSD | 8 | -243.02 | 0.191 | 0.881 | 50.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | symbol=XAUUSD | 8 | -243.02 | 0.191 | 0.881 | 50.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | symbol=USDJPY | 4 | -192.53 | 0.0 | 1.279 | 25.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | symbol=USDJPY | 3 | -144.18 | 0.0 | 1.016 | 33.33 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | symbol=EURJPY | 1 | -50.96 | 0.0 | 1.348 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | symbol=EURJPY | 1 | -50.4 | 0.0 | 1.717 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | symbol=GBPJPY | 1 | -48.41 | 0.0 | 0.694 | 100.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | symbol=GBPJPY | 1 | -48.41 | 0.0 | 0.694 | 100.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | symbol=EURUSD | 3 | 4.56 | 1.049 | 0.955 | 66.67 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | symbol=EURUSD | 4 | 99.87 | 2.048 | 1.289 | 50.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | direction=LONG | 14 | -516.66 | 0.16 | 0.817 | 71.43 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | direction=SHORT | 13 | -200.02 | 0.559 | 1.38 | 46.15 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | direction=LONG | 14 | -515.34 | 0.161 | 0.817 | 71.43 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | direction=SHORT | 11 | -247.74 | 0.388 | 1.268 | 54.55 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | h4_pullback=38-42_shallow_zone | 8 | -231.05 | 0.302 | 0.927 | 75.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | h4_pullback=42-50 | 8 | -238.62 | 0.194 | 1.247 | 37.5 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | h4_pullback=50-58 | 6 | 2.09 | 1.011 | 1.179 | 50.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | h4_pullback=58-62_deep_zone | 5 | -249.1 | 0.0 | 0.983 | 80.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | h4_pullback=38-42_shallow_zone | 8 | -233.46 | 0.3 | 0.927 | 75.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | h4_pullback=42-50 | 7 | -187.86 | 0.234 | 1.129 | 42.86 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | h4_pullback=50-58 | 5 | -92.66 | 0.515 | 1.03 | 60.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | h4_pullback=58-62_deep_zone | 5 | -249.1 | 0.0 | 0.983 | 80.0 |

## 2026-Q1 Failure Types

| scenario | failure_type | trades | net | avg MFE R | reached 1R % | false break % |
|---|---|---:|---:|---:|---:|---:|
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | false_breakout | 15 | -684.59 | 0.649 | 26.67 | 100.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | late_breakout | 2 | -101.48 | 1.308 | 50.0 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | no_follow_through | 1 | -70.76 | 0.11 | 0.0 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | target_too_far | 5 | -212.26 | 1.546 | 100.0 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | false_breakout | 15 | -683.27 | 0.649 | 26.67 | 100.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | late_breakout | 1 | -53.13 | 0.549 | 0.0 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | no_follow_through | 1 | -70.76 | 0.11 | 0.0 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | target_too_far | 5 | -211.7 | 1.62 | 100.0 | 0.0 |

## Failure Layer

| scenario | setup_failure_layer | trades | net | avg MFE R | false break % |
|---|---|---:|---:|---:|---:|
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | M15_neckline_quality_problem | 16 | -755.35 | 0.615 | 93.75 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | SL_TP_design_problem | 5 | -212.26 | 1.546 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | entry_timing_problem | 2 | -101.48 | 1.308 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | M15_neckline_quality_problem | 16 | -754.03 | 0.615 | 93.75 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | SL_TP_design_problem | 5 | -211.7 | 1.62 | 0.0 |
| Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | entry_timing_problem | 1 | -53.13 | 0.549 | 0.0 |

## Clean Label Recheck

| period | scenario | label | trades | PF | net | avg MFE R | false break % |
|---|---|---|---:|---:|---:|---:|---:|
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | clean_nested_nwave_entry | 1 | 0.0 | -50.82 | 0.581 | 100.0 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | neckline_break_initial | 2 | 2.159 | 52.25 | 1.294 | 50.0 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | neckline_break_late | 10 | 0.792 | -72.85 | 1.212 | 60.0 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | clean_nested_nwave_entry | 1 | 0.0 | -50.82 | 0.581 | 100.0 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | neckline_break_initial | 2 | 2.159 | 52.25 | 1.294 | 50.0 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | neckline_break_late | 9 | 0.52 | -168.37 | 1.102 | 66.67 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | neckline_break_late | 2 | 1.514 | 27.14 | 1.401 | 100.0 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | neckline_break_late | 2 | 1.514 | 27.14 | 1.401 | 100.0 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | neckline_break_initial | 3 | 3.311 | 114.14 | 2.015 | 66.67 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | neckline_break_late | 2 |  | 199.43 | 2.208 | 0.0 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | neckline_break_initial | 3 | 3.311 | 114.14 | 2.015 | 66.67 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | neckline_break_late | 1 |  | 98.56 | 2.181 | 0.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | chasing_after_break | 2 | 0.0 | -93.77 | 0.811 | 100.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | clean_nested_nwave_entry | 3 | 0.0 | -130.75 | 1.048 | 100.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | neckline_break_initial | 5 | 0.0 | -243.67 | 0.578 | 60.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | neckline_break_late | 17 | 0.586 | -248.49 | 1.278 | 47.06 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | chasing_after_break | 2 | 0.0 | -93.77 | 0.811 | 100.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | clean_nested_nwave_entry | 3 | 0.0 | -130.75 | 1.048 | 100.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | neckline_break_initial | 5 | 0.0 | -243.67 | 0.578 | 60.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | neckline_break_late | 15 | 0.464 | -294.89 | 1.182 | 53.33 |

## Diagnostic True-Clean Proxy

A temporary `true_clean_candidate` proxy was added only in analysis, not in EA logic. It requires: original clean/initial label, entry close within 0.4 ATR of neckline, close strength >= 0.6, no immediate close back inside neckline, mid-zone H4 pullback, and SL ATR < 2.0.

| period | scenario | true_clean_candidate | trades | PF | net | avg MFE R | false break % |
|---|---|---:|---:|---:|---:|---:|---:|
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 0 | 13 | 0.84 | -71.42 | 1.176 | 61.54 |
| 2025-02 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 0 | 12 | 0.626 | -166.94 | 1.091 | 66.67 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 0 | 2 | 1.514 | 27.14 | 1.401 | 100.0 |
| 2025-08 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 0 | 2 | 1.514 | 27.14 | 1.401 | 100.0 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 0 | 5 | 7.348 | 313.57 | 2.092 | 40.0 |
| 2025-10 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 0 | 4 | 5.306 | 212.7 | 2.056 | 50.0 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 0 | 27 | 0.33 | -716.68 | 1.088 | 59.26 |
| 2026-Q1 | Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R | 0 | 25 | 0.251 | -763.08 | 1.015 | 64.0 |

## Judgement

1. 2026-Q1 collapse is primarily a neckline-quality and follow-through problem, with secondary H1/H4 context weakness. It is not solved by symbol or direction narrowing.
2. The current neckline break check confirms a close beyond a level, but does not sufficiently grade breakout body strength, close location, retest behavior, or room to follow through.
3. 2R is sometimes too far, but the more important issue is that a large portion of losers do not develop enough MFE to justify any simple RewardR retune.
4. `clean_nested_nwave_entry` is currently a structural pass label, not a human-grade clean breakout label.
5. The next v2, if attempted, should add fixed quality gates around breakout strength and false-break behavior before touching RewardR or SL.

## Outputs

- Failure decomposition: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_failure_decomposition.csv`
- Neckline quality: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_quality.csv`
- MFE/MAE/R reach: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_mfe_mae_r_reach.csv`
- v2 gate candidates: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_v2_gate_candidates.md`
