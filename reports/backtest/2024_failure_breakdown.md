# 2024 Failure Breakdown

Target branch: `v4_micro_or_candle_lower_tf_sl_1_2R`

## Worst Deltas vs Baseline

### symbol

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| XAUUSD | 557.61 | -263.19 | -820.8 | 122 | 160 |
| GBPJPY | 428.99 | -49.04 | -478.03 | 19 | 23 |
| USDJPY | 303.58 | 29.35 | -274.23 | 19 | 28 |
| EURUSD | -49.92 | -50.46 | -0.54 | 1 | 1 |
| AUDJPY | -106.14 | -47.13 | 59.01 | 2 | 1 |
| GBPUSD | -161.57 | -38.38 | 123.19 | 3 | 5 |
| EURJPY | -258.3 | -3.5 | 254.8 | 12 | 22 |

### direction

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| LONG | 542.88 | -49.53 | -592.41 | 106 | 137 |
| SHORT | 171.37 | -372.82 | -544.19 | 72 | 103 |

### session

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| server_00_07 | -130.71 | -594.45 | -463.74 | 35 | 52 |
| server_08_15 | 785.49 | 365.65 | -419.84 | 82 | 101 |
| server_16_23 | 59.47 | -193.55 | -253.02 | 61 | 87 |

### month

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| 2024-03 | 327.9 | -199.78 | -527.68 | 15 | 17 |
| 2024-05 | 61.24 | -414.79 | -476.03 | 6 | 13 |
| 2024-07 | 301.21 | -86.27 | -387.48 | 19 | 24 |
| 2024-04 | 275.97 | 7.17 | -268.8 | 12 | 13 |
| 2024-11 | 521.73 | 320.96 | -200.77 | 21 | 31 |
| 2024-12 | -84.9 | -139.45 | -54.55 | 9 | 16 |
| 2024-01 | -138.0 | -92.81 | 45.19 | 30 | 32 |
| 2024-06 | -7.04 | 44.44 | 51.48 | 12 | 13 |

### reversal_signal_type

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| unclear | 714.25 | 0.0 | -714.25 | 178 | 0 |
| candle_reversal | 0.0 | -650.57 | -650.57 | 0 | 155 |
| micro_break | 0.0 | 228.22 | 228.22 | 0 | 85 |

### wave_audit_label

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| chasing_entry | 834.97 | -311.88 | -1146.85 | 156 | 206 |
| late_entry | 19.92 | -197.04 | -216.96 | 7 | 14 |
| third_wave_middle | 77.3 | -14.8 | -92.1 | 6 | 9 |
| unclear | 27.84 | 64.79 | 36.95 | 2 | 3 |
| third_wave_initial | -245.78 | 36.58 | 282.36 | 7 | 8 |

### sl_width_atr_bucket

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| normal_1.5-2.5 | 408.03 | -711.62 | -1119.65 | 45 | 103 |
| wide_2.5-3.5 | 405.02 | 168.9 | -236.12 | 62 | 78 |
| very_wide_3.5+ | -70.83 | -29.94 | 40.89 | 61 | 19 |
| tight_<1.5 | -27.97 | 150.31 | 178.28 | 10 | 40 |

### trend_age_bucket

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| 00-05 | 1016.6 | -89.29 | -1105.89 | 32 | 31 |
| 21+ | -18.89 | -87.72 | -68.83 | 5 | 4 |
| 11-20 | 210.25 | 166.63 | -43.62 | 50 | 69 |
| 06-10 | -493.71 | -411.97 | 81.74 | 91 | 136 |

### atr_percentile_bucket

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| p80-100 | 157.01 | -502.62 | -659.63 | 46 | 72 |
| p20-50 | 307.24 | -129.29 | -436.53 | 59 | 69 |
| p50-80 | 78.34 | 18.94 | -59.4 | 39 | 62 |
| p00-20 | 171.66 | 190.62 | 18.96 | 34 | 37 |

### adx_bucket

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| medium_0.35-0.55 | 457.13 | -254.09 | -711.22 | 39 | 55 |
| weak_<0.35 | -174.24 | -527.84 | -353.6 | 75 | 90 |
| strong_0.55-0.75 | -17.87 | -140.73 | -122.86 | 36 | 52 |
| very_strong_0.75+ | 449.23 | 500.31 | 51.08 | 28 | 43 |

### pullback_depth_bucket

| group | baseline net | target net | delta | baseline trades | target trades |
|---|---:|---:|---:|---:|---:|
| deep_38-62 | 534.63 | -541.01 | -1075.64 | 70 | 87 |
| very_deep_62-100 | 793.15 | 202.75 | -590.4 | 61 | 97 |
| shallow_<20 | -28.74 | 58.69 | 87.43 | 8 | 7 |
| normal_20-38 | -584.79 | -142.78 | 442.01 | 39 | 49 |

## Diagnosis

- The LowerTF SL branch reduced stop distance and increased trade count, but 2024 did not pay for the added entries.
- XAUUSD flipped from a baseline gain to a loss in 2024, so the branch is not merely adding FX noise.
- Short-side deterioration is visible, but filtering direction alone would violate the common-branch objective and would not explain all year-to-year variation.
