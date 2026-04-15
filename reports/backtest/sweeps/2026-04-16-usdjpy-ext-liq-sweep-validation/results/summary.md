# USDJPY External Liquidity Sweep Failed Acceptance Family Validation

- total runs: 81
- selected phase: `phase1`
- fixed slice: `Tier A strict`, `short-only`, `partial 38.2`, `final fib 61.8`, `hold 24`, scaffold exit unchanged

## PHASE1

### TRAIN

| slug | pair | level | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-train-m30_m10_m3-pday-reclaim | M30 x M10 x M3 | previous_day_extreme | reclaim_close_confirm | 31 | 0.08 | -300.59 | -9.70 | 3.01 | 25.81 | 3.08 | -14.14 | -0.3308 |
| phase1-train-m15_m5_m3-pday-reclaim | M15 x M5 x M3 | previous_day_extreme | reclaim_close_confirm | 38 | 0.41 | -314.72 | -8.28 | 4.04 | 60.53 | 9.60 | -35.70 | -0.3427 |
| phase1-train-m15_m5_m3-pday-swing | M15 x M5 x M3 | previous_day_extreme | recent_swing_breakdown | 28 | 0.34 | -303.41 | -10.84 | 3.91 | 64.29 | 8.60 | -45.82 | -0.4704 |
| phase1-train-m30_m10_m3-pday-swing | M30 x M10 x M3 | previous_day_extreme | recent_swing_breakdown | 19 | 0.07 | -142.63 | -7.51 | 1.43 | 31.58 | 1.85 | -11.83 | -0.2646 |
| phase1-train-m15_m10_m3-pday-reclaim | M15 x M10 x M3 | previous_day_extreme | reclaim_close_confirm | 17 | 0.03 | -599.95 | -35.29 | 6.00 | 35.29 | 3.20 | -56.28 | -1.2723 |
| phase1-train-m15_m5_m3-pday-retest | M15 x M5 x M3 | previous_day_extreme | retest_failure | 17 | 0.74 | -39.85 | -2.34 | 0.73 | 52.94 | 12.42 | -18.95 | -0.0895 |
| phase1-train-m15_m5_m3-m30-reclaim | M15 x M5 x M3 | m30_prior_swing | reclaim_close_confirm | 12 | 0.06 | -127.03 | -10.59 | 1.35 | 33.33 | 2.00 | -16.88 | -0.3712 |
| phase1-train-m15_m10_m3-pday-swing | M15 x M10 x M3 | previous_day_extreme | recent_swing_breakdown | 9 | 0.17 | -61.30 | -6.81 | 0.61 | 44.44 | 3.12 | -14.76 | -0.2584 |
| phase1-train-m15_m10_m3-pday-retest | M15 x M10 x M3 | previous_day_extreme | retest_failure | 5 | 0.00 | -62.76 | -12.55 | 0.63 | 0.00 | 0.00 | -12.55 | -0.3686 |
| phase1-train-m30_m10_m3-pday-retest | M30 x M10 x M3 | previous_day_extreme | retest_failure | 5 | 0.00 | -68.93 | -13.79 | 0.69 | 0.00 | 0.00 | -13.79 | -0.4035 |
| phase1-train-m15_m5_m3-m30-swing | M15 x M5 x M3 | m30_prior_swing | recent_swing_breakdown | 4 | 0.05 | -57.63 | -14.41 | 0.61 | 50.00 | 1.44 | -30.26 | -0.5582 |
| phase1-train-m15_m5_m3-m30-retest | M15 x M5 x M3 | m30_prior_swing | retest_failure | 3 | 0.00 | -65.00 | -21.67 | 0.65 | 0.00 | 0.00 | -21.67 | -0.6308 |
| phase1-train-m30_m10_m3-ctx-reclaim | M30 x M10 x M3 | context_prior_swing | reclaim_close_confirm | 1 | 0.00 | -19.58 | -19.58 | 0.20 | 0.00 | 0.00 | -19.58 | -0.5647 |
| phase1-train-m30_m10_m3-m30-reclaim | M30 x M10 x M3 | m30_prior_swing | reclaim_close_confirm | 1 | 0.00 | -19.58 | -19.58 | 0.20 | 0.00 | 0.00 | -19.58 | -0.5647 |
| phase1-train-m30_m10_m3-ctx-swing | M30 x M10 x M3 | context_prior_swing | recent_swing_breakdown | 1 | 0.00 | -25.27 | -25.27 | 0.25 | 0.00 | 0.00 | -25.27 | -0.7385 |
| phase1-train-m30_m10_m3-m30-swing | M30 x M10 x M3 | m30_prior_swing | recent_swing_breakdown | 1 | 0.00 | -25.27 | -25.27 | 0.25 | 0.00 | 0.00 | -25.27 | -0.7385 |
| phase1-train-m30_m10_m3-ctx-retest | M30 x M10 x M3 | context_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m30_m10_m3-m30-retest | M30 x M10 x M3 | m30_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m5_m3-ctx-reclaim | M15 x M5 x M3 | context_prior_swing | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m5_m3-ctx-retest | M15 x M5 x M3 | context_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m5_m3-ctx-swing | M15 x M5 x M3 | context_prior_swing | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m10_m3-ctx-reclaim | M15 x M10 x M3 | context_prior_swing | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m10_m3-ctx-retest | M15 x M10 x M3 | context_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m10_m3-ctx-swing | M15 x M10 x M3 | context_prior_swing | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m10_m3-m30-reclaim | M15 x M10 x M3 | m30_prior_swing | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m10_m3-m30-retest | M15 x M10 x M3 | m30_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-m15_m10_m3-m30-swing | M15 x M10 x M3 | m30_prior_swing | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By External Level

| level | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| context_prior_swing | 2 | 0.00 | -44.85 | -0.6516 | 0.00 | 0.00 | 0.00 |
| m30_prior_swing | 18 | 0.04 | -294.51 | -0.4767 | 16.67 | 100.00 | 0.00 |
| previous_day_extreme | 133 | 0.23 | -1894.14 | -0.4210 | 27.07 | 100.00 | 52.78 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| reclaim_close_confirm | 80 | 0.16 | -1381.45 | -0.5105 | 25.00 | 100.00 | 50.00 |
| retest_failure | 26 | 0.32 | -236.54 | -0.2660 | 15.38 | 100.00 | 75.00 |
| recent_swing_breakdown | 47 | 0.23 | -615.51 | -0.3857 | 31.91 | 100.00 | 40.00 |

### OOS

| slug | pair | level | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-oos-m15_m5_m3-m30-reclaim | M15 x M5 x M3 | m30_prior_swing | reclaim_close_confirm | 5 | 0.00 | 30.10 | 6.02 | 0.00 | 100.00 | 6.02 | 0.00 | 0.2919 |
| phase1-oos-m15_m5_m3-m30-swing | M15 x M5 x M3 | m30_prior_swing | recent_swing_breakdown | 3 | 0.00 | 22.78 | 7.59 | 0.00 | 100.00 | 7.59 | 0.00 | 0.3301 |
| phase1-oos-m15_m10_m3-ctx-retest | M15 x M10 x M3 | context_prior_swing | retest_failure | 1 | 0.00 | 25.47 | 25.47 | 0.00 | 100.00 | 25.47 | 0.00 | 0.7300 |
| phase1-oos-m15_m10_m3-ctx-swing | M15 x M10 x M3 | context_prior_swing | recent_swing_breakdown | 1 | 0.00 | 10.00 | 10.00 | 0.00 | 100.00 | 10.00 | 0.00 | 0.2911 |
| phase1-oos-m15_m5_m3-ctx-reclaim | M15 x M5 x M3 | context_prior_swing | reclaim_close_confirm | 2 | 0.00 | 6.53 | 3.27 | 0.00 | 100.00 | 3.27 | 0.00 | 0.1872 |
| phase1-oos-m15_m5_m3-ctx-swing | M15 x M5 x M3 | context_prior_swing | recent_swing_breakdown | 2 | 0.00 | 6.53 | 3.27 | 0.00 | 100.00 | 3.27 | 0.00 | 0.1872 |
| phase1-oos-m15_m10_m3-ctx-reclaim | M15 x M10 x M3 | context_prior_swing | reclaim_close_confirm | 1 | 0.00 | 1.72 | 1.72 | 0.00 | 100.00 | 1.72 | 0.00 | 0.0500 |
| phase1-oos-m30_m10_m3-pday-reclaim | M30 x M10 x M3 | previous_day_extreme | reclaim_close_confirm | 1 | 0.00 | -10.64 | -10.64 | 0.11 | 0.00 | 0.00 | -10.64 | -0.3159 |
| phase1-oos-m30_m10_m3-pday-retest | M30 x M10 x M3 | previous_day_extreme | retest_failure | 1 | 0.00 | -10.64 | -10.64 | 0.11 | 0.00 | 0.00 | -10.64 | -0.3159 |
| phase1-oos-m15_m5_m3-pday-reclaim | M15 x M5 x M3 | previous_day_extreme | reclaim_close_confirm | 1 | 0.00 | -26.82 | -26.82 | 0.27 | 0.00 | 0.00 | -26.82 | -0.7666 |
| phase1-oos-m15_m5_m3-pday-retest | M15 x M5 x M3 | previous_day_extreme | retest_failure | 1 | 0.00 | -26.82 | -26.82 | 0.27 | 0.00 | 0.00 | -26.82 | -0.7666 |
| phase1-oos-m30_m10_m3-ctx-reclaim | M30 x M10 x M3 | context_prior_swing | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m3-ctx-retest | M30 x M10 x M3 | context_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m3-ctx-swing | M30 x M10 x M3 | context_prior_swing | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m3-m30-reclaim | M30 x M10 x M3 | m30_prior_swing | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m3-m30-retest | M30 x M10 x M3 | m30_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m3-m30-swing | M30 x M10 x M3 | m30_prior_swing | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m3-pday-swing | M30 x M10 x M3 | previous_day_extreme | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m5_m3-ctx-retest | M15 x M5 x M3 | context_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m5_m3-m30-retest | M15 x M5 x M3 | m30_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m5_m3-pday-swing | M15 x M5 x M3 | previous_day_extreme | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m10_m3-m30-reclaim | M15 x M10 x M3 | m30_prior_swing | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m10_m3-m30-retest | M15 x M10 x M3 | m30_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m10_m3-m30-swing | M15 x M10 x M3 | m30_prior_swing | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m10_m3-pday-reclaim | M15 x M10 x M3 | previous_day_extreme | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m10_m3-pday-retest | M15 x M10 x M3 | previous_day_extreme | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m10_m3-pday-swing | M15 x M10 x M3 | previous_day_extreme | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By External Level

| level | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| context_prior_swing | 5 | 0.00 | 50.25 | 0.2891 | 40.00 | 100.00 | 0.00 |
| m30_prior_swing | 5 | 0.00 | 52.88 | 0.3071 | 60.00 | 100.00 | 0.00 |
| previous_day_extreme | 4 | 0.00 | -74.92 | -0.5413 | 0.00 | 0.00 | 0.00 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| reclaim_close_confirm | 7 | 1.02 | 0.89 | 0.0043 | 42.86 | 100.00 | 0.00 |
| retest_failure | 3 | 0.68 | -11.99 | -0.1175 | 0.00 | 0.00 | 0.00 |
| recent_swing_breakdown | 4 | 0.00 | 39.31 | 0.2846 | 50.00 | 100.00 | 0.00 |

### ACTUAL

| slug | pair | level | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-actual-m15_m5_m3-pday-reclaim | M15 x M5 x M3 | previous_day_extreme | reclaim_close_confirm | 72 | 0.44 | -491.01 | -6.82 | 4.91 | 55.56 | 9.50 | -27.21 | -0.2682 |
| phase1-actual-m30_m10_m3-pday-reclaim | M30 x M10 x M3 | previous_day_extreme | reclaim_close_confirm | 56 | 0.23 | -431.21 | -7.70 | 4.31 | 39.29 | 5.86 | -16.47 | -0.2707 |
| phase1-actual-m15_m5_m3-pday-swing | M15 x M5 x M3 | previous_day_extreme | recent_swing_breakdown | 46 | 0.45 | -304.58 | -6.62 | 3.91 | 63.04 | 8.61 | -32.60 | -0.2789 |
| phase1-actual-m30_m10_m3-pday-swing | M30 x M10 x M3 | previous_day_extreme | recent_swing_breakdown | 34 | 0.24 | -195.57 | -5.75 | 1.96 | 50.00 | 3.68 | -15.19 | -0.2107 |
| phase1-actual-m15_m10_m3-pday-reclaim | M15 x M10 x M3 | previous_day_extreme | reclaim_close_confirm | 28 | 0.04 | -746.99 | -26.68 | 7.47 | 28.57 | 3.99 | -38.95 | -0.9224 |
| phase1-actual-m15_m5_m3-pday-retest | M15 x M5 x M3 | previous_day_extreme | retest_failure | 28 | 0.75 | -63.82 | -2.28 | 0.93 | 50.00 | 13.74 | -18.29 | -0.0834 |
| phase1-actual-m15_m5_m3-m30-reclaim | M15 x M5 x M3 | m30_prior_swing | reclaim_close_confirm | 25 | 0.26 | -187.74 | -7.51 | 2.32 | 48.00 | 5.40 | -19.43 | -0.2726 |
| phase1-actual-m15_m10_m3-pday-swing | M15 x M10 x M3 | previous_day_extreme | recent_swing_breakdown | 16 | 0.15 | -138.07 | -8.63 | 1.38 | 37.50 | 4.20 | -16.33 | -0.3081 |
| phase1-actual-m15_m5_m3-m30-swing | M15 x M5 x M3 | m30_prior_swing | recent_swing_breakdown | 13 | 0.43 | -70.90 | -5.45 | 1.09 | 61.54 | 6.61 | -24.76 | -0.2026 |
| phase1-actual-m30_m10_m3-pday-retest | M30 x M10 x M3 | previous_day_extreme | retest_failure | 8 | 0.00 | -140.01 | -17.50 | 1.40 | 0.00 | 0.00 | -17.50 | -0.5087 |
| phase1-actual-m15_m10_m3-pday-retest | M15 x M10 x M3 | previous_day_extreme | retest_failure | 7 | 0.00 | -123.03 | -17.58 | 1.23 | 0.00 | 0.00 | -17.58 | -0.5099 |
| phase1-actual-m15_m5_m3-m30-retest | M15 x M5 x M3 | m30_prior_swing | retest_failure | 7 | 0.13 | -100.66 | -14.38 | 1.15 | 28.57 | 7.40 | -23.09 | -0.4880 |
| phase1-actual-m15_m10_m3-ctx-retest | M15 x M10 x M3 | context_prior_swing | retest_failure | 1 | 0.00 | 25.47 | 25.47 | 0.00 | 100.00 | 25.47 | 0.00 | 0.7300 |
| phase1-actual-m15_m10_m3-ctx-swing | M15 x M10 x M3 | context_prior_swing | recent_swing_breakdown | 1 | 0.00 | 10.00 | 10.00 | 0.00 | 100.00 | 10.00 | 0.00 | 0.2911 |
| phase1-actual-m15_m5_m3-ctx-reclaim | M15 x M5 x M3 | context_prior_swing | reclaim_close_confirm | 2 | 0.00 | 6.53 | 3.27 | 0.00 | 100.00 | 3.27 | 0.00 | 0.1872 |
| phase1-actual-m15_m5_m3-ctx-swing | M15 x M5 x M3 | context_prior_swing | recent_swing_breakdown | 2 | 0.00 | 6.53 | 3.27 | 0.00 | 100.00 | 3.27 | 0.00 | 0.1872 |
| phase1-actual-m15_m10_m3-ctx-reclaim | M15 x M10 x M3 | context_prior_swing | reclaim_close_confirm | 1 | 0.00 | 1.72 | 1.72 | 0.00 | 100.00 | 1.72 | 0.00 | 0.0500 |
| phase1-actual-m30_m10_m3-ctx-reclaim | M30 x M10 x M3 | context_prior_swing | reclaim_close_confirm | 1 | 0.00 | -19.58 | -19.58 | 0.20 | 0.00 | 0.00 | -19.58 | -0.5647 |
| phase1-actual-m30_m10_m3-m30-reclaim | M30 x M10 x M3 | m30_prior_swing | reclaim_close_confirm | 1 | 0.00 | -19.58 | -19.58 | 0.20 | 0.00 | 0.00 | -19.58 | -0.5647 |
| phase1-actual-m30_m10_m3-ctx-swing | M30 x M10 x M3 | context_prior_swing | recent_swing_breakdown | 1 | 0.00 | -25.27 | -25.27 | 0.25 | 0.00 | 0.00 | -25.27 | -0.7385 |
| phase1-actual-m30_m10_m3-m30-swing | M30 x M10 x M3 | m30_prior_swing | recent_swing_breakdown | 1 | 0.00 | -25.27 | -25.27 | 0.25 | 0.00 | 0.00 | -25.27 | -0.7385 |
| phase1-actual-m30_m10_m3-ctx-retest | M30 x M10 x M3 | context_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-actual-m30_m10_m3-m30-retest | M30 x M10 x M3 | m30_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-actual-m15_m5_m3-ctx-retest | M15 x M5 x M3 | context_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-actual-m15_m10_m3-m30-reclaim | M15 x M10 x M3 | m30_prior_swing | reclaim_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-actual-m15_m10_m3-m30-retest | M15 x M10 x M3 | m30_prior_swing | retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-actual-m15_m10_m3-m30-swing | M15 x M10 x M3 | m30_prior_swing | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By External Level

| level | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| context_prior_swing | 7 | 1.12 | 5.40 | 0.0204 | 28.57 | 100.00 | 0.00 |
| m30_prior_swing | 38 | 0.25 | -404.15 | -0.3081 | 23.68 | 100.00 | 33.33 |
| previous_day_extreme | 234 | 0.29 | -2634.29 | -0.3309 | 26.07 | 100.00 | 57.38 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| reclaim_close_confirm | 149 | 0.25 | -1887.86 | -0.3737 | 24.83 | 100.00 | 51.35 |
| retest_failure | 44 | 0.37 | -402.05 | -0.2653 | 15.91 | 100.00 | 71.43 |
| recent_swing_breakdown | 86 | 0.35 | -743.13 | -0.2517 | 32.56 | 100.00 | 50.00 |


