# ThirdWave v4 Early Reversal Short-Period Summary

## Scope

- Compared current `ThirdWave_regime_BOTH_all_5m`, v2 `ThirdWave_v2_audit_filtered_BOTH_all_5m`, v3 `ThirdWave_v3_entry_timing_BOTH_all_5m`, and v4 `ThirdWave_v4_early_reversal_BOTH_all_5m`.
- All runs used `ENTRY_SELECTION_ALL_SCORE_PASSING`, 5-minute scan, `DIAG_ENTRY_ONLY`, and no parameter optimization.
- Existing ThirdWave/v2/v3 logic was rerun in the same build to verify behavior isolation.
- RewardR, SL/TP, spread guard, and timeframe settings were not changed.

## Results

| Period | Variant | Trades | PF | Expected Payoff | Net | Avg R | Max DD % | XAU Share % | LONG Net | SHORT Net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-02 | current | 16 | 2.293 | 23.36 | 373.68 | 0.502 | 0.99 | 81.25 | 237.09 | 136.59 |
| 2025-02 | v2_audit_filtered | 3 |  | 71.53 | 214.6 | 1.517 | 0.0 | 33.33 | 139.66 | 74.94 |
| 2025-02 | v3_entry_timing | 1 |  | 73.77 | 73.77 | 1.502 | 0.0 | 0.0 | 73.77 | 0 |
| 2025-02 | v4_early_reversal | 27 | 1.422 | 10.3 | 278.18 | 0.226 | 1.95 | 48.15 | -26.73 | 304.91 |
| 2025-08 | current | 13 | 0.899 | -3.09 | -40.11 | -0.032 | 2.45 | 92.31 | -70.61 | 30.5 |
| 2025-08 | v2_audit_filtered | 7 | 1.118 | 3.38 | 23.64 | 0.078 | 1.49 | 85.71 | -28.71 | 52.35 |
| 2025-08 | v3_entry_timing | 1 | 0.0 | -51.0 | -51.0 | -1.027 | 0.51 | 100.0 | 0 | -51.0 |
| 2025-08 | v4_early_reversal | 33 | 1.215 | 5.94 | 195.88 | 0.142 | 3.67 | 84.85 | 276.69 | -80.81 |
| 2025-10 | current | 20 | 1.823 | 17.26 | 345.18 | 0.378 | 1.75 | 80.0 | 236.4 | 108.78 |
| 2025-10 | v2_audit_filtered | 15 | 3.043 | 31.89 | 478.4 | 0.673 | 0.98 | 80.0 | 425.04 | 53.36 |
| 2025-10 | v3_entry_timing | 0 |  | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| 2025-10 | v4_early_reversal | 38 | 1.077 | 2.09 | 79.24 | 0.048 | 2.48 | 73.68 | 222.62 | -143.38 |
| 2026-Q1 | current | 60 | 1.402 | 10.17 | 610.21 | 0.154 | 2.65 | 83.33 | 87.84 | 522.37 |
| 2026-Q1 | v2_audit_filtered | 33 | 1.638 | 14.66 | 483.62 | 0.265 | 1.93 | 90.91 | 101.35 | 382.27 |
| 2026-Q1 | v3_entry_timing | 2 | 1.506 | 11.79 | 23.58 | 0.262 | 0.47 | 100.0 | 23.58 | 0 |
| 2026-Q1 | v4_early_reversal | 96 | 1.397 | 10.91 | 1047.07 | 0.131 | 4.72 | 78.12 | -169.9 | 1216.97 |

## Annual Test Gate

- current average PF=1.604, v4 average PF=1.278
- current average R=0.251, v4 average R=0.137
- v3 trades=4, v4 trades=194, current trades=109
- v4/current trade count ratio=178.0%
- current good-label share=5.5%, v4 good-label share=6.2%
- current chasing share=91.7%, v4 chasing share=87.6%
- current FX net=241.33, v4 FX net=145.16
- v4 XAUUSD share=74.2%
- v4 largest direction share=51.0%
- Decision: short-period gate did not pass cleanly. Annual validation was not executed in this cycle.

## Label Aggregate

| Variant | Label | Trades | PF | Net | Avg R |
|---|---|---:|---:|---:|---:|
| current | chasing_entry | 100 | 1.456 | 1107.37 | 0.207 |
| current | late_entry | 2 |  | 156.84 | 1.57 |
| current | third_wave_initial | 1 | 0.0 | -46.62 | -1.001 |
| current | third_wave_middle | 5 | 2.204 | 120.98 | 0.514 |
| current | unclear | 1 | 0.0 | -49.61 | -1.007 |
| v2_audit_filtered | chasing_entry | 50 | 2.112 | 1106.18 | 0.438 |
| v2_audit_filtered | late_entry | 1 |  | 70.14 | 1.51 |
| v2_audit_filtered | third_wave_initial | 1 | 0.0 | -46.62 | -1.001 |
| v2_audit_filtered | third_wave_middle | 6 | 1.466 | 70.56 | 0.257 |
| v3_entry_timing | third_wave_initial | 1 | 0.0 | -46.62 | -1.001 |
| v3_entry_timing | third_wave_middle | 3 | 2.823 | 92.97 | 0.667 |
| v4_early_reversal | chasing_entry | 170 | 1.25 | 1171.04 | 0.098 |
| v4_early_reversal | late_entry | 8 | 0.833 | -41.85 | -0.071 |
| v4_early_reversal | third_wave_initial | 6 | 7.184 | 324.67 | 1.097 |
| v4_early_reversal | third_wave_middle | 6 | 1.647 | 89.01 | 0.257 |
| v4_early_reversal | unclear | 4 | 1.585 | 57.5 | 0.248 |

## Reversal Signal Aggregate

| Variant | Signal | Trades | PF | Net | Avg R |
|---|---|---:|---:|---:|---:|
| current | unclear | 109 | 1.491 | 1288.96 | 0.224 |
| v2_audit_filtered | unclear | 58 | 2.006 | 1200.26 | 0.413 |
| v3_entry_timing | unclear | 4 | 1.475 | 46.35 | 0.25 |
| v4_early_reversal | candle_reversal | 80 | 1.422 | 905.1 | 0.137 |
| v4_early_reversal | confirmed_fractal_reclaim | 3 | 0.808 | -16.37 | -0.163 |
| v4_early_reversal | early_higher_low | 49 | 0.968 | -44.57 | -0.024 |
| v4_early_reversal | early_lower_high | 41 | 1.194 | 231.44 | 0.107 |
| v4_early_reversal | micro_break | 20 | 2.589 | 569.45 | 0.625 |
| v4_early_reversal | momentum_turn | 1 | 0.0 | -44.68 | -1.002 |

## Judgement

- v4 tests the revised hypothesis: the lower-timeframe reversal detector may be late, so earlier reversal signatures are recorded and allowed before confirmed-fractal reclaim/breakdown.
- Promotion depends on restoring trade count versus v3 while reducing current ThirdWave's chasing-entry share and improving PF or average R.
- If the annual gate fails, v4 should be held as diagnostic evidence rather than promoted as a research branch.
