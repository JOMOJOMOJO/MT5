# USDJPY N-Wave Third-Leg Family Validation

- total runs: 27
- selected phase: `phase1`
- fixed slice: `Tier A strict`, `short-only`, `partial 38.2`, `final fib 61.8`, `hold 24`, scaffold exit unchanged

## PHASE1

### TRAIN

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-train-m15_m5_m3-core-swing | M15 x M5 x M3 | recent_swing_breakdown | 105 | 0.15 | -647.33 | -6.17 | 6.47 | 20.95 | 5.38 | -9.23 | -0.2124 |
| phase1-train-m30_m10_m5-core-swing | M30 x M10 x M5 | recent_swing_breakdown | 94 | 0.42 | -343.66 | -3.66 | 3.59 | 23.40 | 11.38 | -8.25 | -0.1159 |
| phase1-train-m15_m5_m3-core-close | M15 x M5 x M3 | invalidation_close_break | 92 | 0.31 | -439.70 | -4.78 | 4.62 | 42.39 | 4.95 | -11.94 | -0.1911 |
| phase1-train-m30_m10_m5-core-close | M30 x M10 x M5 | invalidation_close_break | 77 | 0.53 | -283.59 | -3.68 | 3.11 | 42.86 | 9.87 | -13.84 | -0.1339 |
| phase1-train-m15_m5_m3-core-retest | M15 x M5 x M3 | retest_reject | 4 | 0.05 | -24.78 | -6.20 | 0.26 | 25.00 | 1.31 | -8.70 | -0.2384 |
| phase1-train-m30_m10_m5-core-retest | M30 x M10 x M5 | retest_reject | 4 | 0.02 | -44.40 | -11.10 | 0.45 | 25.00 | 1.08 | -15.16 | -0.4260 |
| phase1-train-h1_m15_m5-core-close | H1 x M15 x M5 | invalidation_close_break | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-h1_m15_m5-core-retest | H1 x M15 x M5 | retest_reject | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-train-h1_m15_m5-core-swing | H1 x M15 x M5 | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| invalidation_close_break | 130 | 0.41 | -723.29 | -0.1642 | 30.00 | 100.00 | 35.90 |
| retest_reject | 6 | 0.02 | -69.18 | -0.3322 | 33.33 | 100.00 | 0.00 |
| recent_swing_breakdown | 176 | 0.27 | -990.99 | -0.1658 | 13.07 | 100.00 | 30.43 |

### OOS

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-oos-m15_m5_m3-core-swing | M15 x M5 x M3 | recent_swing_breakdown | 10 | 0.17 | -62.64 | -6.26 | 0.63 | 20.00 | 6.52 | -9.46 | -0.2009 |
| phase1-oos-m15_m5_m3-core-close | M15 x M5 x M3 | invalidation_close_break | 6 | 0.25 | -40.15 | -6.69 | 0.45 | 33.33 | 6.72 | -13.40 | -0.2317 |
| phase1-oos-m30_m10_m5-core-swing | M30 x M10 x M5 | recent_swing_breakdown | 3 | 0.00 | -9.86 | -3.29 | 0.10 | 0.00 | 0.00 | -3.29 | -0.0957 |
| phase1-oos-h1_m15_m5-core-close | H1 x M15 x M5 | invalidation_close_break | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-h1_m15_m5-core-retest | H1 x M15 x M5 | retest_reject | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-h1_m15_m5-core-swing | H1 x M15 x M5 | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m5-core-close | M30 x M10 x M5 | invalidation_close_break | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m30_m10_m5-core-retest | M30 x M10 x M5 | retest_reject | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m5_m3-core-retest | M15 x M5 x M3 | retest_reject | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| invalidation_close_break | 5 | 0.25 | -40.15 | -0.2317 | 20.00 | 100.00 | 100.00 |
| retest_reject | 0 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 |
| recent_swing_breakdown | 12 | 0.15 | -72.50 | -0.1746 | 8.33 | 100.00 | 100.00 |

### ACTUAL

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-actual-m15_m5_m3-core-swing | M15 x M5 x M3 | recent_swing_breakdown | 174 | 0.17 | -993.60 | -5.71 | 9.94 | 20.11 | 5.68 | -8.58 | -0.1962 |
| phase1-actual-m30_m10_m5-core-swing | M30 x M10 x M5 | recent_swing_breakdown | 135 | 0.41 | -496.38 | -3.68 | 5.05 | 23.70 | 10.73 | -8.15 | -0.1190 |
| phase1-actual-m15_m5_m3-core-close | M15 x M5 x M3 | invalidation_close_break | 151 | 0.31 | -716.60 | -4.75 | 7.21 | 43.71 | 4.95 | -12.27 | -0.1881 |
| phase1-actual-m30_m10_m5-core-close | M30 x M10 x M5 | invalidation_close_break | 116 | 0.65 | -282.05 | -2.43 | 3.48 | 48.28 | 9.50 | -13.57 | -0.0990 |
| phase1-actual-m30_m10_m5-core-retest | M30 x M10 x M5 | retest_reject | 7 | 0.23 | -42.61 | -6.09 | 0.54 | 42.86 | 4.27 | -13.85 | -0.2457 |
| phase1-actual-m15_m5_m3-core-retest | M15 x M5 x M3 | retest_reject | 5 | 0.04 | -33.81 | -6.76 | 0.35 | 20.00 | 1.31 | -8.78 | -0.2443 |
| phase1-actual-h1_m15_m5-core-close | H1 x M15 x M5 | invalidation_close_break | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-actual-h1_m15_m5-core-retest | H1 x M15 x M5 | retest_reject | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-actual-h1_m15_m5-core-swing | H1 x M15 x M5 | recent_swing_breakdown | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| invalidation_close_break | 202 | 0.45 | -1017.60 | -0.1497 | 31.19 | 100.00 | 34.92 |
| retest_reject | 9 | 0.15 | -76.42 | -0.2451 | 33.33 | 100.00 | 33.33 |
| recent_swing_breakdown | 274 | 0.26 | -1485.47 | -0.1624 | 12.41 | 100.00 | 32.35 |


