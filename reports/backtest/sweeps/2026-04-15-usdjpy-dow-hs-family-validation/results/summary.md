# USDJPY Dow Fractal Head-And-Shoulders Family Validation

- total runs: 63
- selected phase: `all`
- fixed slice: `Tier A strict`, `short-only`, `partial 38.2`, `final fib 61.8`, `hold 24`, scaffold exit unchanged

## PHASE1

### TRAIN

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-train-m15_m5_m3-neck_close_confirm | M15 x M5 x M3 | neck_close_confirm | 33 | 0.19 | -230.68 | -6.99 | 2.32 | 33.33 | 5.06 | -13.01 | -0.2570 |
| phase1-train-h1_m15_m3-neck_close_confirm | H1 x M15 x M3 | neck_close_confirm | 26 | 0.31 | -58.09 | -2.23 | 0.70 | 38.46 | 2.59 | -5.25 | -0.0776 |
| phase1-train-m15_m5_m3-recent_swing_break | M15 x M5 x M3 | recent_swing_break | 16 | 0.23 | -91.75 | -5.73 | 1.09 | 25.00 | 6.83 | -9.92 | -0.1934 |
| phase1-train-h1_m15_m3-recent_swing_break | H1 x M15 x M3 | recent_swing_break | 12 | 0.37 | -18.43 | -1.54 | 0.28 | 16.67 | 5.40 | -2.92 | -0.0461 |
| phase1-train-h1_m15_m3-neck_retest_failure | H1 x M15 x M3 | neck_retest_failure | 2 | 0.00 | -10.31 | -5.16 | 0.10 | 0.00 | 0.00 | -5.16 | -0.1525 |
| phase1-train-m15_m5_m3-neck_retest_failure | M15 x M5 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| neck_close_confirm | 48 | 0.22 | -282.56 | -0.1748 | 20.83 | 100.00 | 40.00 |
| neck_retest_failure | 2 | 0.00 | -10.31 | -0.1525 | 0.00 | 0.00 | 0.00 |
| recent_swing_break | 26 | 0.26 | -110.18 | -0.1254 | 7.69 | 100.00 | 100.00 |

### OOS

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-oos-h1_m15_m3-recent_swing_break | H1 x M15 x M3 | recent_swing_break | 6 | 0.00 | -10.97 | -1.83 | 0.11 | 0.00 | 0.00 | -1.83 | -0.0545 |
| phase1-oos-m15_m5_m3-recent_swing_break | M15 x M5 x M3 | recent_swing_break | 1 | 0.00 | -6.67 | -6.67 | 0.07 | 0.00 | 0.00 | -6.67 | -0.1911 |
| phase1-oos-h1_m15_m3-neck_close_confirm | H1 x M15 x M3 | neck_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-h1_m15_m3-neck_retest_failure | H1 x M15 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m5_m3-neck_close_confirm | M15 x M5 x M3 | neck_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase1-oos-m15_m5_m3-neck_retest_failure | M15 x M5 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| neck_close_confirm | 0 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 |
| neck_retest_failure | 0 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 |
| recent_swing_break | 7 | 0.00 | -17.64 | -0.0740 | 0.00 | 0.00 | 0.00 |

### ACTUAL

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase1-actual-m15_m5_m3-neck_close_confirm | M15 x M5 x M3 | neck_close_confirm | 56 | 0.28 | -301.83 | -5.39 | 3.17 | 41.07 | 5.19 | -12.76 | -0.2047 |
| phase1-actual-h1_m15_m3-neck_close_confirm | H1 x M15 x M3 | neck_close_confirm | 43 | 0.66 | -47.10 | -1.10 | 0.70 | 46.51 | 4.64 | -6.08 | -0.0392 |
| phase1-actual-m15_m5_m3-recent_swing_break | M15 x M5 x M3 | recent_swing_break | 25 | 0.15 | -162.32 | -6.49 | 1.73 | 20.00 | 5.75 | -9.55 | -0.2086 |
| phase1-actual-h1_m15_m3-recent_swing_break | H1 x M15 x M3 | recent_swing_break | 23 | 0.39 | -37.47 | -1.63 | 0.38 | 17.39 | 5.97 | -3.23 | -0.0513 |
| phase1-actual-h1_m15_m3-neck_retest_failure | H1 x M15 x M3 | neck_retest_failure | 4 | 0.33 | -13.04 | -3.26 | 0.20 | 25.00 | 6.53 | -6.52 | -0.0967 |
| phase1-actual-m15_m5_m3-neck_retest_failure | M15 x M5 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| neck_close_confirm | 78 | 0.38 | -342.95 | -0.1304 | 25.64 | 100.00 | 40.00 |
| neck_retest_failure | 4 | 0.33 | -13.04 | -0.0967 | 0.00 | 0.00 | 0.00 |
| recent_swing_break | 45 | 0.21 | -199.79 | -0.1317 | 6.67 | 100.00 | 66.67 |


## PHASE2

### TRAIN

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase2-train-m15_m10_m3-neck_close_confirm | M15 x M10 x M3 | neck_close_confirm | 36 | 0.31 | -131.59 | -3.66 | 1.51 | 36.11 | 4.52 | -8.28 | -0.1208 |
| phase2-train-m15_m5_m3-neck_close_confirm | M15 x M5 x M3 | neck_close_confirm | 33 | 0.19 | -230.68 | -6.99 | 2.32 | 33.33 | 5.06 | -13.01 | -0.2570 |
| phase2-train-m30_m10_m3-neck_close_confirm | M30 x M10 x M3 | neck_close_confirm | 26 | 0.56 | -56.91 | -2.19 | 0.84 | 34.62 | 8.18 | -7.68 | -0.0789 |
| phase2-train-m15_m10_m5-neck_close_confirm | M15 x M10 x M5 | neck_close_confirm | 26 | 0.99 | -1.12 | -0.04 | 0.69 | 50.00 | 7.73 | -7.82 | 0.0156 |
| phase2-train-m30_m15_m3-neck_close_confirm | M30 x M15 x M3 | neck_close_confirm | 22 | 0.51 | -35.26 | -1.60 | 0.35 | 40.91 | 4.02 | -5.50 | -0.0534 |
| phase2-train-m15_m10_m3-recent_swing_break | M15 x M10 x M3 | recent_swing_break | 19 | 0.20 | -83.50 | -4.39 | 1.01 | 15.79 | 6.81 | -6.50 | -0.1389 |
| phase2-train-m15_m5_m3-recent_swing_break | M15 x M5 x M3 | recent_swing_break | 16 | 0.23 | -91.75 | -5.73 | 1.09 | 25.00 | 6.83 | -9.92 | -0.1934 |
| phase2-train-m30_m15_m3-recent_swing_break | M30 x M15 x M3 | recent_swing_break | 14 | 0.26 | -31.43 | -2.25 | 0.31 | 35.71 | 2.21 | -4.72 | -0.0698 |
| phase2-train-m30_m10_m3-recent_swing_break | M30 x M10 x M3 | recent_swing_break | 12 | 0.21 | -58.78 | -4.90 | 0.59 | 16.67 | 7.98 | -7.47 | -0.1625 |
| phase2-train-m15_m10_m5-recent_swing_break | M15 x M10 x M5 | recent_swing_break | 9 | 0.23 | -33.34 | -3.70 | 0.41 | 77.78 | 1.40 | -21.56 | -0.1369 |
| phase2-train-m15_m10_m3-neck_retest_failure | M15 x M10 x M3 | neck_retest_failure | 4 | 0.00 | -31.89 | -7.97 | 0.32 | 0.00 | 0.00 | -7.97 | -0.2337 |
| phase2-train-m15_m10_m5-neck_retest_failure | M15 x M10 x M5 | neck_retest_failure | 3 | 1.08 | 0.59 | 0.20 | 0.07 | 66.67 | 3.95 | -7.30 | 0.0103 |
| phase2-train-m30_m15_m3-neck_retest_failure | M30 x M15 x M3 | neck_retest_failure | 2 | 0.00 | -9.92 | -4.96 | 0.10 | 0.00 | 0.00 | -4.96 | -0.1466 |
| phase2-train-m30_m10_m3-neck_retest_failure | M30 x M10 x M3 | neck_retest_failure | 2 | 0.00 | 2.15 | 1.08 | 0.00 | 100.00 | 1.08 | 0.00 | 0.0631 |
| phase2-train-m15_m5_m3-neck_retest_failure | M15 x M5 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| neck_close_confirm | 119 | 0.42 | -438.98 | -0.1089 | 18.49 | 100.00 | 50.00 |
| neck_retest_failure | 9 | 0.20 | -39.07 | -0.1271 | 22.22 | 100.00 | 50.00 |
| recent_swing_break | 63 | 0.22 | -298.80 | -0.1406 | 11.11 | 100.00 | 28.57 |

### OOS

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase2-oos-m30_m10_m3-neck_close_confirm | M30 x M10 x M3 | neck_close_confirm | 5 | 0.00 | -124.18 | -24.84 | 1.24 | 0.00 | 0.00 | -24.84 | -0.7275 |
| phase2-oos-m30_m10_m3-recent_swing_break | M30 x M10 x M3 | recent_swing_break | 4 | 0.00 | -64.89 | -16.22 | 0.65 | 0.00 | 0.00 | -16.22 | -0.4681 |
| phase2-oos-m15_m10_m3-recent_swing_break | M15 x M10 x M3 | recent_swing_break | 1 | 0.00 | -1.94 | -1.94 | 0.02 | 0.00 | 0.00 | -1.94 | -0.0569 |
| phase2-oos-m15_m5_m3-recent_swing_break | M15 x M5 x M3 | recent_swing_break | 1 | 0.00 | -6.67 | -6.67 | 0.07 | 0.00 | 0.00 | -6.67 | -0.1911 |
| phase2-oos-m30_m10_m3-neck_retest_failure | M30 x M10 x M3 | neck_retest_failure | 1 | 0.00 | -11.10 | -11.10 | 0.11 | 0.00 | 0.00 | -11.10 | -0.3246 |
| phase2-oos-m15_m10_m5-neck_close_confirm | M15 x M10 x M5 | neck_close_confirm | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | 0.00 | -36.51 | -1.0472 |
| phase2-oos-m15_m10_m5-recent_swing_break | M15 x M10 x M5 | recent_swing_break | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | 0.00 | -36.51 | -1.0472 |
| phase2-oos-m15_m10_m3-neck_close_confirm | M15 x M10 x M3 | neck_close_confirm | 1 | 0.00 | -35.75 | -35.75 | 0.36 | 0.00 | 0.00 | -35.75 | -1.0623 |
| phase2-oos-m30_m15_m3-neck_close_confirm | M30 x M15 x M3 | neck_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase2-oos-m30_m15_m3-neck_retest_failure | M30 x M15 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase2-oos-m30_m15_m3-recent_swing_break | M30 x M15 x M3 | recent_swing_break | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase2-oos-m15_m10_m3-neck_retest_failure | M15 x M10 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase2-oos-m15_m5_m3-neck_close_confirm | M15 x M5 x M3 | neck_close_confirm | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase2-oos-m15_m5_m3-neck_retest_failure | M15 x M5 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |
| phase2-oos-m15_m10_m5-neck_retest_failure | M15 x M10 x M5 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| neck_close_confirm | 7 | 0.00 | -196.44 | -0.8210 | 0.00 | 0.00 | 0.00 |
| neck_retest_failure | 1 | 0.00 | -11.10 | -0.3246 | 0.00 | 0.00 | 0.00 |
| recent_swing_break | 7 | 0.00 | -110.01 | -0.4526 | 0.00 | 0.00 | 0.00 |

### ACTUAL

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phase2-actual-m15_m5_m3-neck_close_confirm | M15 x M5 x M3 | neck_close_confirm | 56 | 0.28 | -301.83 | -5.39 | 3.17 | 41.07 | 5.19 | -12.76 | -0.2047 |
| phase2-actual-m15_m10_m3-neck_close_confirm | M15 x M10 x M3 | neck_close_confirm | 46 | 0.27 | -190.72 | -4.15 | 1.92 | 34.78 | 4.42 | -8.71 | -0.1334 |
| phase2-actual-m30_m10_m3-neck_close_confirm | M30 x M10 x M3 | neck_close_confirm | 40 | 0.32 | -197.70 | -4.94 | 2.06 | 32.50 | 7.31 | -10.84 | -0.1766 |
| phase2-actual-m30_m15_m3-neck_close_confirm | M30 x M15 x M3 | neck_close_confirm | 36 | 0.57 | -53.94 | -1.50 | 0.54 | 38.89 | 5.20 | -5.76 | -0.0527 |
| phase2-actual-m15_m10_m5-neck_close_confirm | M15 x M10 x M5 | neck_close_confirm | 36 | 0.75 | -38.35 | -1.07 | 0.90 | 44.44 | 7.36 | -7.80 | -0.0270 |
| phase2-actual-m15_m5_m3-recent_swing_break | M15 x M5 x M3 | recent_swing_break | 25 | 0.15 | -162.32 | -6.49 | 1.73 | 20.00 | 5.75 | -9.55 | -0.2086 |
| phase2-actual-m15_m10_m3-recent_swing_break | M15 x M10 x M3 | recent_swing_break | 23 | 0.17 | -102.02 | -4.44 | 1.03 | 13.04 | 6.81 | -6.12 | -0.1394 |
| phase2-actual-m30_m15_m3-recent_swing_break | M30 x M15 x M3 | recent_swing_break | 20 | 0.30 | -54.63 | -2.73 | 0.55 | 30.00 | 3.86 | -5.55 | -0.0839 |
| phase2-actual-m30_m10_m3-recent_swing_break | M30 x M10 x M3 | recent_swing_break | 20 | 0.21 | -113.29 | -5.66 | 1.22 | 20.00 | 7.55 | -8.97 | -0.1890 |
| phase2-actual-m15_m10_m5-recent_swing_break | M15 x M10 x M5 | recent_swing_break | 12 | 0.12 | -72.65 | -6.05 | 0.73 | 58.33 | 1.40 | -16.49 | -0.2143 |
| phase2-actual-m30_m15_m3-neck_retest_failure | M30 x M15 x M3 | neck_retest_failure | 5 | 0.23 | -21.39 | -4.28 | 0.21 | 20.00 | 6.53 | -6.98 | -0.1281 |
| phase2-actual-m30_m10_m3-neck_retest_failure | M30 x M10 x M3 | neck_retest_failure | 6 | 1.22 | 2.92 | 0.49 | 0.10 | 66.67 | 4.12 | -6.79 | 0.0249 |
| phase2-actual-m15_m10_m3-neck_retest_failure | M15 x M10 x M3 | neck_retest_failure | 4 | 0.00 | -31.89 | -7.97 | 0.32 | 0.00 | 0.00 | -7.97 | -0.2337 |
| phase2-actual-m15_m10_m5-neck_retest_failure | M15 x M10 x M5 | neck_retest_failure | 3 | 1.08 | 0.59 | 0.20 | 0.07 | 66.67 | 3.95 | -7.30 | 0.0103 |
| phase2-actual-m15_m5_m3-neck_retest_failure | M15 x M5 x M3 | neck_retest_failure | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 |

#### Aggregate By Trigger

| trigger | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| neck_close_confirm | 178 | 0.38 | -766.19 | -0.1272 | 19.10 | 100.00 | 50.00 |
| neck_retest_failure | 15 | 0.38 | -49.77 | -0.0970 | 20.00 | 100.00 | 66.67 |
| recent_swing_break | 92 | 0.18 | -504.91 | -0.1631 | 8.70 | 100.00 | 37.50 |


