# ThirdWave v2 Short-Period Summary

## Scope

- Compared current `ThirdWave_regime_BOTH_all_5m` against `ThirdWave_v2_audit_filtered_BOTH_all_5m`.
- Both used `ENTRY_SELECTION_ALL_SCORE_PASSING`, 5-minute scan, `DIAG_ENTRY_ONLY`, and no parameter optimization.
- Existing ThirdWave logic was rerun in the same build to verify behavior isolation.

## Results

| Period | Variant | Trades | PF | Expected Payoff | Net | Avg R | Max DD % | XAU Share % | LONG Net | SHORT Net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-02 | current | 16 | 2.293 | 23.36 | 373.68 | 0.502 | 0.99 | 81.25 | 237.09 | 136.59 |
| 2025-02 | v2_audit_filtered | 3 |  | 71.53 | 214.6 | 1.517 | 0.0 | 33.33 | 139.66 | 74.94 |
| 2025-08 | current | 13 | 0.899 | -3.09 | -40.11 | -0.032 | 2.45 | 92.31 | -70.61 | 30.5 |
| 2025-08 | v2_audit_filtered | 7 | 1.118 | 3.38 | 23.64 | 0.078 | 1.49 | 85.71 | -28.71 | 52.35 |
| 2025-10 | current | 20 | 1.823 | 17.26 | 345.18 | 0.378 | 1.75 | 80.0 | 236.4 | 108.78 |
| 2025-10 | v2_audit_filtered | 15 | 3.043 | 31.89 | 478.4 | 0.673 | 0.98 | 80.0 | 425.04 | 53.36 |
| 2026-Q1 | current | 60 | 1.402 | 10.17 | 610.21 | 0.154 | 2.65 | 83.33 | 87.84 | 522.37 |
| 2026-Q1 | v2_audit_filtered | 33 | 1.638 | 14.66 | 483.62 | 0.265 | 1.93 | 90.91 | 101.35 | 382.27 |

## Annual Test Gate

- current average PF=1.604, v2 average PF=1.450
- current average R=0.251, v2 average R=0.633
- trade count ratio=53.2% (58/109)
- v2 XAUUSD share=84.5%
- v2 largest direction share=63.8%
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

## Judgement

- Current ThirdWave's main issue remains wave-position quality: the short audit is still dominated by `chasing_entry`, not `third_wave_initial`.
- v2 improved average R and reduced drawdown by removing weak structural cases, but it did not turn the model into a clean third-wave-initial entry model.
- This is not just harmless filtering: total trades fell to 53.2% of current, and the remaining v2 sample became more concentrated in XAUUSD.
- v2 is therefore useful as a diagnostic branch, but not yet a validated improvement branch for annual OOS.
- It is not a symbol/direction escape in implementation, but the short-period result still depends too much on XAUUSD to justify broader promotion.
- The next repair should target lower-reversal timing and wave-position classification first. Regime quality is second. SL/TP changes should remain deferred.
- The correct next step is to refine the entry thesis, not run parameter search or annual tests from this v2 version.
