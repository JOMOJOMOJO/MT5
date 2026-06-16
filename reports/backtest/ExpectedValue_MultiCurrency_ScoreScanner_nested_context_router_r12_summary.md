# Nested Context Quality Router RR 1.2 Short Test

This is a bounded diagnostic cycle, not parameter optimization. All runs use H4/H1/M15 Nested N-Wave settings, all-candidates entry, and `InpRewardR=1.20`.

## Aggregate By Scenario

| scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net |
|---|---:|---:|---:|---:|---:|---:|---:|
| breakout_router_all_r12 | 9 | 0.895 | -0.025 | -25.56 | 1.94 | -139.64 | 114.08 |
| context_router_all_r12 | 24 | 1.165 | 0.094 | 93.19 | 1.83 | 47.15 | 46.04 |
| context_router_v2_all_r12 | 19 | 1.3 | 0.154 | 123.93 | 1.81 | 29.09 | 94.84 |
| instant_all_r12 | 49 | 0.946 | -0.014 | -71.14 | 4.92 | -165.57 | 94.43 |
| retest_all_r12 | 25 | 0.701 | -0.214 | -223.6 | 3.12 | -190.34 | -33.26 |

## Best Scenario By Period

| period | scenario | trades | PF | avg_R | net | FX net | XAUUSD net |
|---|---|---:|---:|---:|---:|---:|---:|
| 2025-02 | breakout_router_all_r12 | 2 | 1.232 | 0.105 | 11.11 | -47.83 | 58.94 |
| 2025-08 | retest_all_r12 | 1 |  | 1.206 | 58.52 | 0 | 58.52 |
| 2025-10 | instant_all_r12 | 5 |  | 1.207 | 279.01 | 121.62 | 157.39 |
| 2026-Q1 | context_router_v2_all_r12 | 10 | 1.157 | 0.09 | 34.35 | 73.21 | -38.86 |

## Context Router Label Breakdown

| context_quality_label | trades | PF | avg_R | net |
|---|---:|---:|---:|---:|
| clean_context | 24 | 1.165 | 0.094 | 93.19 |

## Initial Judgement

- Context Router improved aggregate avg_R versus both instant and breakout-router baselines.
- Trade count fell by more than 50% versus instant entry, so any improvement must be treated as filter-driven until OOS supports it.
- Next action should be based on the losing-period/block-summary rows, not another threshold sweep.
