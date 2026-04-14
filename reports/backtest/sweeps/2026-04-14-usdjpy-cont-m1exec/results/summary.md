# USDJPY Continuation M1 Execution Diagnostics

- total runs: 72
- fixed slice: `ENTRY_ON_HIGHER_LOW_BREAK only`, `M15 context`, `M5 setup`, `M1 execution`, `Tier A strict`, `STOP_PULLBACK_LOW`, `TARGET_HYBRID_PARTIAL`, `runner_fib_618`, `ea_managed`

## TRAIN

| slug | pf | net | trades | avg R | partial hit % | be move % | runner hit % | avg bars setup->entry | avg setup->entry pips | avg bars to time stop |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| train-m1_break_close-partial382-h32 | 0.00 | 28.93 | 1 | 0.8400 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 32.00 |
| train-m1_break_close-partial500-h32 | 0.00 | 28.93 | 1 | 0.8400 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 32.00 |
| train-m5_market-partial382-h32 | 1.23 | 8.05 | 2 | 0.1228 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 32.00 |
| train-m5_market-partial500-h32 | 1.23 | 8.05 | 2 | 0.1228 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 32.00 |
| train-m1_micro_stop-partial382-h32 | 1.23 | 8.05 | 2 | 0.1228 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 32.00 |
| train-m1_micro_stop-partial500-h32 | 1.23 | 8.05 | 2 | 0.1228 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 32.00 |
| train-m1_retest_hold-partial382-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| train-m1_retest_hold-partial382-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| train-m1_retest_hold-partial382-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| train-m1_retest_hold-partial500-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| train-m1_retest_hold-partial500-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| train-m1_retest_hold-partial500-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| train-m1_break_close-partial382-h24 | 0.00 | -0.78 | 1 | -0.0226 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 24.00 |
| train-m1_break_close-partial500-h24 | 0.00 | -0.78 | 1 | -0.0226 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 24.00 |
| train-m1_break_close-partial382-h16 | 0.00 | -7.83 | 1 | -0.2274 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 16.00 |
| train-m1_break_close-partial500-h16 | 0.00 | -7.83 | 1 | -0.2274 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 16.00 |
| train-m5_market-partial382-h24 | 0.21 | -27.80 | 2 | -0.4005 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 24.00 |
| train-m5_market-partial500-h24 | 0.21 | -27.80 | 2 | -0.4005 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 24.00 |
| train-m1_micro_stop-partial382-h24 | 0.21 | -27.80 | 2 | -0.4005 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 24.00 |
| train-m1_micro_stop-partial500-h24 | 0.21 | -27.80 | 2 | -0.4005 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 24.00 |
| train-m5_market-partial382-h16 | 0.00 | -36.30 | 2 | -0.5246 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 16.00 |
| train-m5_market-partial500-h16 | 0.00 | -36.30 | 2 | -0.5246 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 16.00 |
| train-m1_micro_stop-partial382-h16 | 0.00 | -36.30 | 2 | -0.5246 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 16.00 |
| train-m1_micro_stop-partial500-h16 | 0.00 | -36.30 | 2 | -0.5246 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 16.00 |

### Execution Mode Aggregate

| execution | pf | net | trades | avg R | partial hit % | runner hit % | time stop count |
|---|---:|---:|---:|---:|---:|---:|---:|
| m5_market | 0.47 | -112.10 | 12 | -0.2674 | 0.00 | 0.00 | 6 |
| m1_micro_stop | 0.47 | -112.10 | 12 | -0.2674 | 0.00 | 0.00 | 6 |
| m1_break_close | 3.36 | 40.64 | 6 | 0.1967 | 0.00 | 0.00 | 6 |
| m1_retest_hold | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0 |

## OOS

| slug | pf | net | trades | avg R | partial hit % | be move % | runner hit % | avg bars setup->entry | avg setup->entry pips | avg bars to time stop |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| oos-m5_market-partial382-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m5_market-partial382-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m5_market-partial382-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m5_market-partial500-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m5_market-partial500-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m5_market-partial500-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_micro_stop-partial382-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_micro_stop-partial382-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_micro_stop-partial382-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_micro_stop-partial500-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_micro_stop-partial500-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_micro_stop-partial500-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_break_close-partial382-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_break_close-partial382-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_break_close-partial382-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_break_close-partial500-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_break_close-partial500-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_break_close-partial500-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_retest_hold-partial382-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_retest_hold-partial382-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_retest_hold-partial382-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_retest_hold-partial500-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_retest_hold-partial500-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m1_retest_hold-partial500-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

### Execution Mode Aggregate

| execution | pf | net | trades | avg R | partial hit % | runner hit % | time stop count |
|---|---:|---:|---:|---:|---:|---:|---:|
| m5_market | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0 |
| m1_micro_stop | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0 |
| m1_break_close | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0 |
| m1_retest_hold | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0 |

## ACTUAL

| slug | pf | net | trades | avg R | partial hit % | be move % | runner hit % | avg bars setup->entry | avg setup->entry pips | avg bars to time stop |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| actual-m1_break_close-partial382-h32 | 0.00 | 28.93 | 1 | 0.8400 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 32.00 |
| actual-m1_break_close-partial500-h32 | 0.00 | 28.93 | 1 | 0.8400 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 32.00 |
| actual-m5_market-partial382-h32 | 2.83 | 69.95 | 4 | 0.6913 | 33.33 | 100.00 | 100.00 | 0.00 | 0.00 | 32.00 |
| actual-m1_micro_stop-partial382-h32 | 2.71 | 65.49 | 4 | 0.6401 | 33.33 | 100.00 | 100.00 | 0.33 | 0.27 | 32.00 |
| actual-m5_market-partial500-h32 | 3.49 | 95.37 | 4 | 0.4828 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 32.00 |
| actual-m1_micro_stop-partial500-h32 | 3.37 | 90.91 | 4 | 0.4699 | 0.00 | 0.00 | 0.00 | 0.33 | 0.27 | 32.00 |
| actual-m5_market-partial382-h24 | 1.89 | 34.10 | 4 | 0.3425 | 33.33 | 100.00 | 100.00 | 0.00 | 0.00 | 24.00 |
| actual-m1_micro_stop-partial382-h24 | 1.77 | 29.64 | 4 | 0.2912 | 33.33 | 100.00 | 100.00 | 0.33 | 0.27 | 24.00 |
| actual-m5_market-partial382-h16 | 1.65 | 25.60 | 4 | 0.2597 | 33.33 | 100.00 | 100.00 | 0.00 | 0.00 | 16.00 |
| actual-m1_micro_stop-partial382-h16 | 1.54 | 21.14 | 4 | 0.2085 | 33.33 | 100.00 | 100.00 | 0.33 | 0.27 | 16.00 |
| actual-m5_market-partial500-h24 | 2.55 | 59.52 | 4 | 0.1339 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 24.00 |
| actual-m1_micro_stop-partial500-h24 | 2.44 | 55.06 | 4 | 0.1210 | 0.00 | 0.00 | 0.00 | 0.33 | 0.27 | 24.00 |
| actual-m5_market-partial500-h16 | 2.29 | 51.02 | 4 | 0.0512 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 16.00 |
| actual-m1_micro_stop-partial500-h16 | 2.18 | 46.56 | 4 | 0.0382 | 0.00 | 0.00 | 0.00 | 0.33 | 0.27 | 16.00 |
| actual-m1_retest_hold-partial382-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| actual-m1_retest_hold-partial382-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| actual-m1_retest_hold-partial382-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| actual-m1_retest_hold-partial500-h16 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| actual-m1_retest_hold-partial500-h24 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| actual-m1_retest_hold-partial500-h32 | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| actual-m1_break_close-partial382-h24 | 0.00 | -0.78 | 1 | -0.0226 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 24.00 |
| actual-m1_break_close-partial500-h24 | 0.00 | -0.78 | 1 | -0.0226 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 24.00 |
| actual-m1_break_close-partial382-h16 | 0.00 | -7.83 | 1 | -0.2274 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 16.00 |
| actual-m1_break_close-partial500-h16 | 0.00 | -7.83 | 1 | -0.2274 | 0.00 | 0.00 | 0.00 | 1.00 | 3.50 | 16.00 |

### Execution Mode Aggregate

| execution | pf | net | trades | avg R | partial hit % | runner hit % | time stop count |
|---|---:|---:|---:|---:|---:|---:|---:|
| m5_market | 1.84 | 195.40 | 18 | 0.3269 | 16.67 | 100.00 | 6 |
| m1_micro_stop | 1.77 | 179.71 | 18 | 0.2948 | 16.67 | 100.00 | 6 |
| m1_break_close | 3.36 | 40.64 | 6 | 0.1967 | 0.00 | 0.00 | 6 |
| m1_retest_hold | 0.00 | 0.00 | 0 | 0.0000 | 0.00 | 0.00 | 0 |

