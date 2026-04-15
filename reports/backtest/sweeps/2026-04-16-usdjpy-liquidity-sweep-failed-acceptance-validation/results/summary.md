# USDJPY Liquidity Sweep Failed Acceptance Family Validation

- total runs: 27
- selected phase: `phase1`
- fixed slice: `Tier A strict`, `short-only`, `partial 38.2`, `final fib 61.8`, `hold 24`, scaffold exit unchanged

## PHASE1

### TRAIN

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-train-m15_m5_m3-reclaim_close_confirm | M15 x M5 x M3 | reclaim_close_confirm | 210 | 0.40 | -1249.33 | -5.95 | 13.19 | 38.57 | 10.26 | -16.13 | -0.2271 |
| phase1-train-m15_m10_m3-reclaim_close_confirm | M15 x M10 x M3 | reclaim_close_confirm | 131 | 0.33 | -799.89 | -6.11 | 8.42 | 36.64 | 8.07 | -14.31 | -0.1981 |
| phase1-train-m30_m10_m3-reclaim_close_confirm | M30 x M10 x M3 | reclaim_close_confirm | 110 | 0.57 | -390.67 | -3.55 | 4.23 | 42.73 | 10.90 | -14.33 | -0.1254 |
| phase1-train-m15_m5_m3-recent_swing_breakdown | M15 x M5 x M3 | recent_swing_breakdown | 106 | 0.39 | -622.84 | -5.88 | 6.61 | 39.62 | 9.51 | -15.97 | -0.2241 |
| phase1-train-m15_m10_m3-recent_swing_breakdown | M15 x M10 x M3 | recent_swing_breakdown | 70 | 0.24 | -613.83 | -8.77 | 6.32 | 35.71 | 7.80 | -17.97 | -0.2774 |
| phase1-train-m30_m10_m3-recent_swing_breakdown | M30 x M10 x M3 | recent_swing_breakdown | 68 | 0.47 | -280.57 | -4.13 | 3.00 | 45.59 | 7.95 | -14.24 | -0.1411 |
| phase1-train-m15_m5_m3-retest_failure | M15 x M5 x M3 | retest_failure | 35 | 0.22 | -324.80 | -9.28 | 3.58 | 28.57 | 9.42 | -16.76 | -0.3172 |
| phase1-train-m30_m10_m3-retest_failure | M30 x M10 x M3 | retest_failure | 21 | 0.72 | -51.18 | -2.44 | 1.22 | 33.33 | 18.38 | -12.84 | -0.0740 |
| phase1-train-m15_m10_m3-retest_failure | M15 x M10 x M3 | retest_failure | 15 | 0.23 | -164.49 | -10.97 | 1.77 | 13.33 | 25.12 | -16.52 | -0.3212 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| reclaim_close_confirm | 395 | 0.40 | -2505.01 | -0.1934 | 13.67 | 103.70 | 38.89 |
| retest_failure | 65 | 0.34 | -540.47 | -0.2433 | 9.23 | 100.00 | 33.33 |
| recent_swing_breakdown | 212 | 0.34 | -1545.20 | -0.2183 | 14.62 | 103.23 | 35.48 |

### OOS

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-oos-m30_m10_m3-reclaim_close_confirm | M30 x M10 x M3 | reclaim_close_confirm | 24 | 0.15 | -230.79 | -9.62 | 2.31 | 37.50 | 4.69 | -18.20 | -0.3329 |
| phase1-oos-m15_m5_m3-reclaim_close_confirm | M15 x M5 x M3 | reclaim_close_confirm | 20 | 0.96 | -7.09 | -0.35 | 0.81 | 60.00 | 14.10 | -22.03 | -0.0122 |
| phase1-oos-m15_m10_m3-reclaim_close_confirm | M15 x M10 x M3 | reclaim_close_confirm | 18 | 0.27 | -163.90 | -9.11 | 1.80 | 38.89 | 8.67 | -20.42 | -0.2674 |
| phase1-oos-m30_m10_m3-recent_swing_breakdown | M30 x M10 x M3 | recent_swing_breakdown | 13 | 0.37 | -67.12 | -5.16 | 0.88 | 46.15 | 6.46 | -15.12 | -0.1771 |
| phase1-oos-m15_m5_m3-recent_swing_breakdown | M15 x M5 x M3 | recent_swing_breakdown | 8 | 2.61 | 58.91 | 7.36 | 0.35 | 75.00 | 15.91 | -18.28 | 0.2105 |
| phase1-oos-m15_m10_m3-recent_swing_breakdown | M15 x M10 x M3 | recent_swing_breakdown | 8 | 0.27 | -80.14 | -10.02 | 0.82 | 25.00 | 14.57 | -18.21 | -0.2951 |
| phase1-oos-m30_m10_m3-retest_failure | M30 x M10 x M3 | retest_failure | 5 | 0.59 | -31.29 | -6.26 | 0.57 | 40.00 | 22.13 | -25.18 | -0.1798 |
| phase1-oos-m15_m10_m3-retest_failure | M15 x M10 x M3 | retest_failure | 3 | 0.00 | 80.17 | 26.72 | 0.00 | 100.00 | 26.72 | 0.00 | 0.7748 |
| phase1-oos-m15_m5_m3-retest_failure | M15 x M5 x M3 | retest_failure | 2 | 2.15 | 15.34 | 7.67 | 0.13 | 50.00 | 28.64 | -13.30 | 0.2179 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| reclaim_close_confirm | 56 | 0.41 | -398.30 | -0.2088 | 8.93 | 100.00 | 20.00 |
| retest_failure | 10 | 1.72 | 64.22 | 0.1861 | 0.00 | 0.00 | 0.00 |
| recent_swing_breakdown | 27 | 0.65 | -88.35 | -0.0972 | 7.41 | 100.00 | 0.00 |

### ACTUAL

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-actual-m15_m5_m3-reclaim_close_confirm | M15 x M5 x M3 | reclaim_close_confirm | 334 | 0.43 | -1781.59 | -5.33 | 18.13 | 42.51 | 9.35 | -16.20 | -0.2123 |
| phase1-actual-m15_m10_m3-reclaim_close_confirm | M15 x M10 x M3 | reclaim_close_confirm | 225 | 0.32 | -1395.90 | -6.20 | 14.10 | 37.33 | 7.77 | -14.53 | -0.2154 |
| phase1-actual-m30_m10_m3-reclaim_close_confirm | M30 x M10 x M3 | reclaim_close_confirm | 206 | 0.48 | -917.27 | -4.45 | 9.35 | 44.17 | 9.12 | -15.20 | -0.1625 |
| phase1-actual-m15_m5_m3-recent_swing_breakdown | M15 x M5 x M3 | recent_swing_breakdown | 174 | 0.46 | -841.51 | -4.84 | 9.18 | 43.68 | 9.62 | -16.05 | -0.1892 |
| phase1-actual-m15_m10_m3-recent_swing_breakdown | M15 x M10 x M3 | recent_swing_breakdown | 118 | 0.29 | -887.63 | -7.52 | 8.88 | 38.14 | 8.23 | -17.23 | -0.2490 |
| phase1-actual-m30_m10_m3-recent_swing_breakdown | M30 x M10 x M3 | recent_swing_breakdown | 121 | 0.43 | -577.90 | -4.78 | 5.78 | 46.28 | 7.68 | -15.51 | -0.1680 |
| phase1-actual-m15_m5_m3-retest_failure | M15 x M5 x M3 | retest_failure | 50 | 0.38 | -370.27 | -7.41 | 4.17 | 30.00 | 14.93 | -16.98 | -0.2548 |
| phase1-actual-m30_m10_m3-retest_failure | M30 x M10 x M3 | retest_failure | 36 | 0.49 | -208.31 | -5.79 | 2.34 | 33.33 | 16.92 | -17.14 | -0.1783 |
| phase1-actual-m15_m10_m3-retest_failure | M15 x M10 x M3 | retest_failure | 29 | 0.46 | -217.95 | -7.52 | 3.40 | 20.69 | 30.33 | -17.39 | -0.2197 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| reclaim_close_confirm | 657 | 0.39 | -4172.32 | -0.2001 | 15.83 | 102.88 | 41.35 |
| retest_failure | 106 | 0.43 | -796.53 | -0.2207 | 8.49 | 100.00 | 33.33 |
| recent_swing_breakdown | 354 | 0.39 | -2354.08 | -0.2014 | 16.10 | 103.51 | 40.35 |


