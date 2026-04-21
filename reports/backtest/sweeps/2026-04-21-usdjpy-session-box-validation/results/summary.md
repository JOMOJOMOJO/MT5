# USDJPY Tokyo-London Session Box Breakout Validation

- total runs: 27
- fixed slice: `both directions`, `Tokyo range -> London breakout`, `partial 38.2`, `final session extension`, `hold 24`, `EA managed exits`

## TRAIN

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| train-m30_m5-close | M30 range x M5 execution | range_close_confirm | 34 | 0.63 | -50.01 | -1.19 | 0.60 | 42.86 | 4.70 | -5.61 | -0.0449 |
| train-m15_m5-close | M15 range x M5 execution | range_close_confirm | 34 | 0.63 | -50.33 | -1.20 | 0.61 | 42.86 | 4.70 | -5.62 | -0.0447 |
| train-m15_m3-close | M15 range x M3 execution | range_close_confirm | 33 | 0.32 | -100.14 | -2.71 | 1.05 | 24.32 | 5.27 | -5.27 | -0.0892 |
| train-m15_m5-continuation | M15 range x M5 execution | breakout_bar_continuation | 32 | 0.94 | -8.09 | -0.20 | 0.50 | 48.78 | 5.84 | -5.95 | -0.0061 |
| train-m30_m5-continuation | M30 range x M5 execution | breakout_bar_continuation | 32 | 0.94 | -8.09 | -0.20 | 0.50 | 48.78 | 5.84 | -5.95 | -0.0060 |
| train-m15_m3-continuation | M15 range x M3 execution | breakout_bar_continuation | 32 | 0.42 | -92.42 | -2.43 | 0.95 | 36.84 | 4.72 | -6.60 | -0.0847 |
| train-m15_m3-retest | M15 range x M3 execution | range_retest_confirm | 32 | 0.34 | -96.36 | -2.68 | 0.96 | 22.22 | 6.19 | -5.21 | -0.0892 |
| train-m15_m5-retest | M15 range x M5 execution | range_retest_confirm | 31 | 0.42 | -83.58 | -2.39 | 0.98 | 31.43 | 5.56 | -6.03 | -0.0807 |
| train-m30_m5-retest | M30 range x M5 execution | range_retest_confirm | 31 | 0.42 | -83.58 | -2.39 | 0.98 | 31.43 | 5.56 | -6.03 | -0.0806 |

### Aggregate By Pair

| bucket | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| M30 range x M5 execution | 97 | 0.65 | -141.68 | -0.0435 | 21.65 | 100.00 | 23.81 |
| M15 range x M5 execution | 97 | 0.65 | -142.00 | -0.0435 | 21.65 | 100.00 | 23.81 |
| M15 range x M3 execution | 97 | 0.36 | -288.92 | -0.0877 | 14.43 | 100.00 | 21.43 |

### Aggregate By Trigger

| bucket | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| range_close_confirm | 101 | 0.52 | -200.48 | -0.0593 | 19.80 | 100.00 | 35.00 |
| breakout_bar_continuation | 96 | 0.73 | -108.60 | -0.0323 | 25.00 | 100.00 | 12.50 |
| range_retest_confirm | 94 | 0.39 | -263.52 | -0.0836 | 12.77 | 100.00 | 25.00 |

### Aggregate By Breakout Type

| breakout type | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| session_high_breakout | 176 | 0.73 | -196.31 | -0.0333 |
| session_low_breakout | 115 | 0.29 | -376.29 | -0.0963 |

### Aggregate By Session Type

| session type | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| tokyo_range_london_break | 291 | 0.55 | -572.60 | -0.0582 |

## OOS

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| oos-m15_m3-close | M15 range x M3 execution | range_close_confirm | 12 | 3.72 | 38.96 | 2.05 | 0.07 | 78.95 | 3.55 | -3.58 | 0.0944 |
| oos-m15_m5-close | M15 range x M5 execution | range_close_confirm | 12 | 0.76 | -7.51 | -0.42 | 0.22 | 61.11 | 2.19 | -4.51 | -0.0171 |
| oos-m30_m5-close | M30 range x M5 execution | range_close_confirm | 12 | 0.76 | -7.51 | -0.42 | 0.22 | 61.11 | 2.19 | -4.51 | -0.0172 |
| oos-m15_m5-continuation | M15 range x M5 execution | breakout_bar_continuation | 11 | 0.41 | -39.30 | -3.27 | 0.53 | 50.00 | 4.62 | -11.17 | -0.1055 |
| oos-m30_m5-continuation | M30 range x M5 execution | breakout_bar_continuation | 11 | 0.41 | -39.30 | -3.27 | 0.53 | 50.00 | 4.62 | -11.17 | -0.1058 |
| oos-m15_m3-continuation | M15 range x M3 execution | breakout_bar_continuation | 11 | 0.17 | -35.89 | -2.56 | 0.41 | 50.00 | 1.07 | -6.20 | -0.0986 |
| oos-m15_m3-retest | M15 range x M3 execution | range_retest_confirm | 7 | 2.20 | 11.58 | 1.05 | 0.10 | 72.73 | 2.65 | -3.21 | 0.0488 |
| oos-m15_m5-retest | M15 range x M5 execution | range_retest_confirm | 6 | 0.21 | -21.35 | -2.67 | 0.27 | 25.00 | 2.76 | -4.48 | -0.1056 |
| oos-m30_m5-retest | M30 range x M5 execution | range_retest_confirm | 6 | 0.21 | -21.35 | -2.67 | 0.27 | 25.00 | 2.76 | -4.48 | -0.1056 |

### Aggregate By Pair

| bucket | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| M15 range x M3 execution | 30 | 1.22 | 14.65 | 0.0130 | 46.67 | 100.00 | 7.14 |
| M15 range x M5 execution | 29 | 0.45 | -68.16 | -0.0689 | 31.03 | 100.00 | 11.11 |
| M30 range x M5 execution | 29 | 0.45 | -68.16 | -0.0691 | 31.03 | 100.00 | 11.11 |

### Aggregate By Trigger

| bucket | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| range_close_confirm | 36 | 1.31 | 23.94 | 0.0200 | 52.78 | 100.00 | 10.53 |
| breakout_bar_continuation | 33 | 0.35 | -114.49 | -0.1033 | 15.15 | 100.00 | 0.00 |
| range_retest_confirm | 19 | 0.50 | -31.12 | -0.0487 | 42.11 | 100.00 | 12.50 |

### Aggregate By Breakout Type

| breakout type | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| session_high_breakout | 51 | 0.77 | -33.86 | -0.0186 |
| session_low_breakout | 37 | 0.48 | -87.81 | -0.0721 |

### Aggregate By Session Type

| session type | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| tokyo_range_london_break | 88 | 0.62 | -121.67 | -0.0411 |

## ACTUAL

| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| actual-m30_m5-close | M30 range x M5 execution | range_close_confirm | 55 | 0.69 | -58.27 | -0.78 | 0.69 | 50.67 | 3.42 | -5.09 | -0.0312 |
| actual-m15_m5-close | M15 range x M5 execution | range_close_confirm | 55 | 0.69 | -59.15 | -0.79 | 0.70 | 50.67 | 3.42 | -5.11 | -0.0313 |
| actual-m15_m3-close | M15 range x M3 execution | range_close_confirm | 54 | 0.79 | -36.14 | -0.51 | 1.09 | 50.70 | 3.88 | -5.03 | -0.0185 |
| actual-m15_m5-continuation | M15 range x M5 execution | breakout_bar_continuation | 52 | 0.88 | -26.40 | -0.39 | 0.81 | 53.73 | 5.15 | -6.84 | -0.0142 |
| actual-m30_m5-continuation | M30 range x M5 execution | breakout_bar_continuation | 52 | 0.88 | -26.40 | -0.39 | 0.81 | 53.73 | 5.15 | -6.84 | -0.0143 |
| actual-m15_m3-continuation | M15 range x M3 execution | breakout_bar_continuation | 52 | 0.48 | -111.03 | -1.63 | 1.37 | 51.47 | 2.99 | -6.53 | -0.0630 |
| actual-m15_m3-retest | M15 range x M3 execution | range_retest_confirm | 48 | 0.70 | -52.07 | -0.85 | 1.09 | 44.26 | 4.53 | -5.13 | -0.0323 |
| actual-m15_m5-retest | M15 range x M5 execution | range_retest_confirm | 46 | 0.53 | -92.24 | -1.62 | 1.23 | 38.60 | 4.79 | -5.65 | -0.0602 |
| actual-m30_m5-retest | M30 range x M5 execution | range_retest_confirm | 46 | 0.53 | -92.88 | -1.63 | 1.24 | 38.60 | 4.79 | -5.67 | -0.0600 |

### Aggregate By Pair

| bucket | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| M15 range x M3 execution | 154 | 0.65 | -199.24 | -0.0378 | 29.87 | 100.00 | 8.70 |
| M30 range x M5 execution | 153 | 0.70 | -177.55 | -0.0341 | 30.07 | 100.00 | 15.22 |
| M15 range x M5 execution | 153 | 0.70 | -177.79 | -0.0342 | 30.07 | 100.00 | 15.22 |

### Aggregate By Trigger

| bucket | trades | pf | net | avg R | partial hit % | be move % | runner hit % |
|---|---:|---:|---:|---:|---:|---:|---:|
| range_close_confirm | 164 | 0.72 | -153.56 | -0.0270 | 34.76 | 100.00 | 15.79 |
| breakout_bar_continuation | 156 | 0.74 | -163.83 | -0.0305 | 29.49 | 100.00 | 6.52 |
| range_retest_confirm | 140 | 0.58 | -237.19 | -0.0505 | 25.00 | 100.00 | 17.14 |

### Aggregate By Breakout Type

| breakout type | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| session_high_breakout | 273 | 0.86 | -137.17 | -0.0146 |
| session_low_breakout | 187 | 0.46 | -417.41 | -0.0657 |

### Aggregate By Session Type

| session type | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| tokyo_range_london_break | 460 | 0.68 | -554.58 | -0.0354 |
