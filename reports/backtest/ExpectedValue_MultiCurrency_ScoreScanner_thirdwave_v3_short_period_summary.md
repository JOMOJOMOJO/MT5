# ThirdWave v3 Entry Timing Short-Period Summary

## Scope

- Compared current `ThirdWave_regime_BOTH_all_5m`, v2 `ThirdWave_v2_audit_filtered_BOTH_all_5m`, and v3 `ThirdWave_v3_entry_timing_BOTH_all_5m`.
- All runs used `ENTRY_SELECTION_ALL_SCORE_PASSING`, 5-minute scan, `DIAG_ENTRY_ONLY`, and no parameter optimization.
- Existing ThirdWave/v2 logic was rerun in the same build to verify behavior isolation.

## Results

| Period | Variant | Trades | PF | Expected Payoff | Net | Avg R | Max DD % | XAU Share % | LONG Net | SHORT Net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-02 | current | 16 | 2.293 | 23.36 | 373.68 | 0.502 | 0.99 | 81.25 | 237.09 | 136.59 |
| 2025-02 | v2_audit_filtered | 3 |  | 71.53 | 214.6 | 1.517 | 0.0 | 33.33 | 139.66 | 74.94 |
| 2025-02 | v3_entry_timing | 1 |  | 73.77 | 73.77 | 1.502 | 0.0 | 0.0 | 73.77 | 0 |
| 2025-08 | current | 13 | 0.899 | -3.09 | -40.11 | -0.032 | 2.45 | 92.31 | -70.61 | 30.5 |
| 2025-08 | v2_audit_filtered | 7 | 1.118 | 3.38 | 23.64 | 0.078 | 1.49 | 85.71 | -28.71 | 52.35 |
| 2025-08 | v3_entry_timing | 1 | 0.0 | -51.0 | -51.0 | -1.027 | 0.51 | 100.0 | 0 | -51.0 |
| 2025-10 | current | 20 | 1.823 | 17.26 | 345.18 | 0.378 | 1.75 | 80.0 | 236.4 | 108.78 |
| 2025-10 | v2_audit_filtered | 15 | 3.043 | 31.89 | 478.4 | 0.673 | 0.98 | 80.0 | 425.04 | 53.36 |
| 2025-10 | v3_entry_timing | 0 |  | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| 2026-Q1 | current | 60 | 1.402 | 10.17 | 610.21 | 0.154 | 2.65 | 83.33 | 87.84 | 522.37 |
| 2026-Q1 | v2_audit_filtered | 33 | 1.638 | 14.66 | 483.62 | 0.265 | 1.93 | 90.91 | 101.35 | 382.27 |
| 2026-Q1 | v3_entry_timing | 2 | 1.506 | 11.79 | 23.58 | 0.262 | 0.47 | 100.0 | 23.58 | 0 |

## Annual Test Gate

- current average PF=1.604, v3 average PF=0.377
- current average R=0.251, v3 average R=0.184
- trade count ratio=3.7% (4/109)
- current good-label share=5.5%, v3 good-label share=100.0%
- current chasing share=91.7%, v3 chasing share=0.0%
- current FX net=241.33, v3 FX net=73.77
- v3 XAUUSD share=75.0%
- v3 largest direction share=75.0%
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

## Judgement

- v3 achieved the diagnostic goal of removing `chasing_entry`: the short-period chasing share fell from 91.7% in current ThirdWave to 0.0% in v3.
- The cost was too high: v3 kept only 4 of 109 comparable trades, or 3.7% of the current sample.
- v3 did not improve the core performance gate: current average PF/avg_R was 1.604/0.251, while v3 was 0.377/0.184.
- FX coverage also weakened: current FX net was 241.33, while v3 FX net was 73.77 from only one FX trade.
- Conclusion: this exact entry-position gate should not be promoted or annual-tested. It is useful evidence that the current detector almost never identifies tradable early third-wave entries.
- Next research should not tighten this v3 gate further. Either rebuild lower-timeframe reversal detection to find earlier entries, or treat ThirdWave as a trend-continuation system and move to Regime Quality v2.
