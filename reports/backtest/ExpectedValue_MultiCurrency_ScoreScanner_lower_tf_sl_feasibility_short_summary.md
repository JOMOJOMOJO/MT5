# LowerTF SL Feasibility Short Test

## Scope

- Actual-order short-period feasibility test only.
- Existing ThirdWave, v2, v3, v4, Phase2, and score scanner defaults remain unchanged.
- `InpThirdWaveSLMode=THIRD_WAVE_SL_LOWER_TF_REVERSAL` is used only by the new research presets.
- RewardR `1.2 / 1.3 / 1.5` are fixed comparison points, not optimized ranges.
- Short windows: 2025-02, 2025-08, 2025-10, 2026-Q1.

## Combined Short-Window Result

| variant | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | avg lot | max lot |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| v4_micro_or_candle_lower_tf_sl_1_2R | 131 | 1.741 | 0.296 | 1966.47 | 3.05 | 549.08 | 1417.39 | 0.119 | 0.61 |
| v4_micro_or_candle_lower_tf_sl_1_3R | 129 | 1.667 | 0.285 | 1868.66 | 3.12 | 394.69 | 1473.97 | 0.119 | 0.61 |
| v4_without_weak_lower_tf_sl_1_2R | 158 | 1.603 | 0.237 | 2027.49 | 3.39 | 201.7 | 1825.79 | 0.132 | 1.0 |
| v4_without_weak_lower_tf_sl_1_3R | 154 | 1.585 | 0.248 | 2001.93 | 3.28 | 301.83 | 1700.1 | 0.133 | 1.0 |
| current_thirdwave_current_sl_1_5R | 109 | 1.491 | 0.224 | 1288.96 | 2.49 | 241.33 | 1047.63 | 0.084 | 0.8 |
| v4_micro_or_candle_current_sl_1_5R | 142 | 1.447 | 0.185 | 1643.28 | 4.02 | 136.48 | 1506.8 | 0.12 | 0.82 |
| v4_micro_or_candle_lower_tf_sl_1_5R | 127 | 1.402 | 0.195 | 1274.4 | 3.53 | -36.33 | 1310.73 | 0.116 | 0.59 |

## Short Gate

| variant | gate | fail reasons |
|---|---:|---|
| v4_micro_or_candle_current_sl_1_5R | False | pf_avgR_not_improved;fx_net_worse |
| v4_micro_or_candle_lower_tf_sl_1_2R | True |  |
| v4_micro_or_candle_lower_tf_sl_1_3R | True |  |
| v4_micro_or_candle_lower_tf_sl_1_5R | False | pf_avgR_not_improved;fx_net_worse |
| v4_without_weak_lower_tf_sl_1_2R | False | fx_net_worse |
| v4_without_weak_lower_tf_sl_1_3R | True |  |

## Decision

At least one branch passed the short gate. Annual BT can be run for the passing branch only.
Best combined PF was `1.741` from `v4_micro_or_candle_lower_tf_sl_1_2R` with `131` trades and avg_R `0.296`.

## Execution Feasibility Notes

- `sl_too_tight`: 500
- `invalid_stops`: 107
- `sl_too_wide`: 28181
- Lot-size feasibility is summarized in the comparison and grouping CSVs.
