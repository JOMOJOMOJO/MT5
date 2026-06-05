# LowerTF SL Feasibility Annual Summary

Annual BT was run because the short-period gate passed for C/D/G.
Annual branches: baseline A plus passing C/D/G only.

| period | variant | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | long net | short net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2024 | current_thirdwave_current_sl_1_5R | 178 | 1.139 | 0.108 | 714.25 | 6.23 | 156.64 | 557.61 | 542.88 | 171.37 |
| 2024 | v4_micro_or_candle_lower_tf_sl_1_2R | 240 | 0.933 | -0.002 | -422.35 | 11.5 | -159.16 | -263.19 | -49.53 | -372.82 |
| 2024 | v4_micro_or_candle_lower_tf_sl_1_3R | 238 | 0.943 | 0.003 | -367.05 | 10.82 | -60.79 | -306.26 | 121.71 | -488.76 |
| 2024 | v4_without_weak_lower_tf_sl_1_3R | 285 | 0.883 | -0.039 | -911.88 | 12.71 | -451.51 | -460.37 | 153.46 | -1065.34 |
| 2025 | current_thirdwave_current_sl_1_5R | 269 | 0.944 | -0.009 | -431.98 | 11.11 | -410.82 | -21.16 | -550.52 | 118.54 |
| 2025 | v4_micro_or_candle_lower_tf_sl_1_2R | 337 | 1.098 | 0.071 | 843.61 | 6.07 | -83.16 | 926.77 | 1389.23 | -545.62 |
| 2025 | v4_micro_or_candle_lower_tf_sl_1_3R | 335 | 1.082 | 0.065 | 724.85 | 6.78 | -284.66 | 1009.51 | 1275.26 | -550.41 |
| 2025 | v4_without_weak_lower_tf_sl_1_3R | 388 | 1.11 | 0.078 | 1118.35 | 9.05 | -520.63 | 1638.98 | 1267.28 | -148.93 |
| 2026YTD | current_thirdwave_current_sl_1_5R | 95 | 1.353 | 0.161 | 865.75 | 2.65 | 9.64 | 856.11 | 104.0 | 761.75 |
| 2026YTD | v4_micro_or_candle_lower_tf_sl_1_2R | 122 | 1.303 | 0.147 | 921.66 | 5.52 | 406.18 | 515.48 | -18.73 | 940.39 |
| 2026YTD | v4_micro_or_candle_lower_tf_sl_1_3R | 122 | 1.244 | 0.118 | 784.84 | 7.37 | 334.04 | 450.8 | -67.67 | 852.51 |
| 2026YTD | v4_without_weak_lower_tf_sl_1_3R | 147 | 1.174 | 0.075 | 674.89 | 7.14 | 216.14 | 458.75 | -41.77 | 716.66 |

## Combined Annual Windows

| variant | trades | PF | avg_R | net | FX net | XAUUSD net |
|---|---:|---:|---:|---:|---:|---:|
| current_thirdwave_current_sl_1_5R | 542 | 1.075 | 0.059 | 1148.02 | -244.54 | 1392.56 |
| v4_micro_or_candle_lower_tf_sl_1_2R | 699 | 1.075 | 0.059 | 1342.92 | 163.86 | 1179.06 |
| v4_micro_or_candle_lower_tf_sl_1_3R | 695 | 1.062 | 0.053 | 1142.64 | -11.41 | 1154.05 |
| v4_without_weak_lower_tf_sl_1_3R | 820 | 1.04 | 0.037 | 881.36 | -756.0 | 1637.36 |

## Decision

Best annual PF is `1.075` from `current_thirdwave_current_sl_1_5R`. The baseline PF is `1.075`.
The LowerTF SL hypothesis is feasible as a narrow research branch, but it is not robust enough for promotion: the short-period improvement does not survive 2024, and annual PF/avg_R do not clearly exceed the baseline across 2024/2025/2026YTD.
`v4_micro_or_candle_lower_tf_sl_1_2R` is the only branch worth parking for later: it improves 2025 and 2026YTD FX net, but 2024 is negative and the annual combined PF/avg_R are effectively tied with the current ThirdWave baseline.
Do not run a broader parameter search from this result. The next useful work is signal/regime quality, not tuning RewardR.
