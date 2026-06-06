# Signal / Regime Quality v2 Diagnostic

## Scope

- No trading logic, RewardR, SL, timeframe, symbol, or direction optimization was performed.
- The analyzer reuses existing annual LowerTF SL feasibility BT artifacts for 2024, 2025, and 2026YTD.
- `trend_strength` is treated as an ADX-style proxy because the current EA logs trend strength rather than raw ADX.
- ATR percentile buckets are computed from the entry/candidate sample per symbol and run, not from all historical bars.

## Main Comparison

| period | variant | trades | PF | avg_R | net | DD% | FX net | XAUUSD net | long net | short net | main loss reason |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 2024 | current_thirdwave_current_sl_1_5R | 178 | 1.139 | 0.108 | 714.25 | 6.9 | 156.64 | 557.61 | 542.88 | 171.37 | reversal_signal_type:unclear (-5144.69) |
| 2024 | v4_micro_or_candle_lower_tf_sl_1_2R | 240 | 0.933 | -0.002 | -422.35 | 11.5 | -159.16 | -263.19 | -49.53 | -372.82 | wave_audit_label:chasing_entry (-5390.71) |
| 2024 | v4_micro_or_candle_lower_tf_sl_1_3R | 238 | 0.943 | 0.003 | -367.05 | 10.82 | -60.79 | -306.26 | 121.71 | -488.76 | wave_audit_label:chasing_entry (-5528.95) |
| 2024 | v4_without_weak_lower_tf_sl_1_3R | 285 | 0.883 | -0.039 | -911.88 | 12.71 | -451.51 | -460.37 | 153.46 | -1065.34 | wave_audit_label:chasing_entry (-6350.35) |
| 2025 | current_thirdwave_current_sl_1_5R | 269 | 0.944 | -0.009 | -431.98 | 11.11 | -410.82 | -21.16 | -550.52 | 118.54 | reversal_signal_type:unclear (-7734.83) |
| 2025 | v4_micro_or_candle_lower_tf_sl_1_2R | 337 | 1.098 | 0.071 | 843.61 | 5.63 | -83.16 | 926.77 | 1389.23 | -545.62 | wave_audit_label:chasing_entry (-7245.29) |
| 2025 | v4_micro_or_candle_lower_tf_sl_1_3R | 335 | 1.082 | 0.065 | 724.85 | 6.68 | -284.66 | 1009.51 | 1275.26 | -550.41 | wave_audit_label:chasing_entry (-7414.99) |
| 2025 | v4_without_weak_lower_tf_sl_1_3R | 388 | 1.11 | 0.078 | 1118.35 | 8.79 | -520.63 | 1638.98 | 1267.28 | -148.93 | wave_audit_label:chasing_entry (-8515.95) |
| 2026YTD | current_thirdwave_current_sl_1_5R | 95 | 1.353 | 0.161 | 865.75 | 2.67 | 9.64 | 856.11 | 104.0 | 761.75 | reversal_signal_type:unclear (-2453.31) |
| 2026YTD | v4_micro_or_candle_lower_tf_sl_1_2R | 122 | 1.303 | 0.147 | 921.66 | 5.52 | 406.18 | 515.48 | -18.73 | 940.39 | wave_audit_label:chasing_entry (-2677.12) |
| 2026YTD | v4_micro_or_candle_lower_tf_sl_1_3R | 122 | 1.244 | 0.118 | 784.84 | 7.37 | 334.04 | 450.8 | -67.67 | 852.51 | wave_audit_label:chasing_entry (-2850.39) |
| 2026YTD | v4_without_weak_lower_tf_sl_1_3R | 147 | 1.174 | 0.075 | 674.89 | 7.14 | 216.14 | 458.75 | -41.77 | 716.66 | wave_audit_label:chasing_entry (-3419.62) |
| ALL_ANNUAL_WINDOWS | current_thirdwave_current_sl_1_5R | 542 | 1.075 | 0.059 | 1148.02 | 10.41 | -244.54 | 1392.56 | 96.36 | 1051.66 | reversal_signal_type:unclear (-15332.83) |
| ALL_ANNUAL_WINDOWS | v4_micro_or_candle_lower_tf_sl_1_2R | 699 | 1.075 | 0.059 | 1342.92 | 11.5 | 163.86 | 1179.06 | 1320.97 | 21.95 | wave_audit_label:chasing_entry (-15313.12) |
| ALL_ANNUAL_WINDOWS | v4_micro_or_candle_lower_tf_sl_1_3R | 695 | 1.062 | 0.053 | 1142.64 | 10.82 | -11.41 | 1154.05 | 1329.3 | -186.66 | wave_audit_label:chasing_entry (-15794.33) |
| ALL_ANNUAL_WINDOWS | v4_without_weak_lower_tf_sl_1_3R | 820 | 1.04 | 0.037 | 881.36 | 15.58 | -756.0 | 1637.36 | 1378.97 | -497.61 | wave_audit_label:chasing_entry (-18285.92) |

## Interpretation

- 2024 failure: `v4_micro_or_candle_lower_tf_sl_1_2R` produced PF `0.933`, net `-422.35`, while baseline produced PF `1.139`, net `714.25`.
- 2025 success: `v4_micro_or_candle_lower_tf_sl_1_2R` improved to PF `1.098`, net `843.61`, but FX net remained `-83.16`.
- 2026YTD success: `v4_micro_or_candle_lower_tf_sl_1_2R` produced PF `1.303`, net `921.66`, and FX net `406.18`.
- Combined annual result stayed flat: PF `1.075`, avg_R `0.059`. This is not enough for promotion.

## Decision

- LowerTF SL remains a parked research branch, not a promotion candidate.
- The 2024 break is not explained by a single broad switch such as XAUUSD only or direction only; the branch changes the loss profile by year.
- The next useful filter candidate must be tested as a fixed regime-quality diagnostic, not as RewardR/SL tuning.
