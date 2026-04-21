# USDJPY Tokyo-London Session Box Breakout Regime Diagnostics

- total runs: 27
- fixed family: `Tokyo 00:00-07:00 box -> London 07:00-16:00 breakout`
- fixed exits: `partial 38.2`, `final session extension`, `hold 24`, `EA managed exits`
- diagnostic focus: `breakout side`, `trigger`, `box width`, `breakout strength`, `breakout timing`, `prev-day alignment`, `M30 prior swing alignment`, `weekday`

## TRAIN

- aggregate trades: `291`
- aggregate PF: `0.55`
- aggregate net: `-572.60`
- avg failed-back-inside bars: `1.07`
- avg MFE before acceptance exit: `1.84`

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

### Aggregate By Breakout Side

| breakout side | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| high_breakout | 176 | 0.73 | -196.31 | -0.0333 |
| low_breakout | 115 | 0.29 | -376.29 | -0.0963 |

### Aggregate By Box Width Bucket

| box width bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| wide | 291 | 0.55 | -572.60 | -0.0582 |

### Aggregate By Breakout Strength Bucket

| breakout strength bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| strong_close | 150 | 0.50 | -332.13 | -0.0652 |
| medium_close | 92 | 0.83 | -60.44 | -0.0202 |
| weak_close | 49 | 0.23 | -180.03 | -0.1084 |

### Aggregate By Breakout Timing Bucket

| breakout timing bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| 60m_plus | 199 | 0.45 | -508.70 | -0.0754 |
| 0_30m | 61 | 0.20 | -249.16 | -0.1215 |
| 30_60m | 31 | 6.57 | 185.26 | 0.1764 |

### Aggregate By Previous Day Alignment

| prev-day alignment | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| far_prev_day_high | 158 | 0.82 | -116.26 | -0.0220 |
| far_prev_day_low | 89 | 0.37 | -252.50 | -0.0833 |
| unavailable | 34 | 0.02 | -168.17 | -0.1471 |
| near_prev_day_low | 10 | 0.11 | -35.67 | -0.1050 |

### Aggregate By M30 Prior Swing Alignment

| m30 swing alignment | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| far_m30_prior_swing_high | 158 | 0.62 | -258.95 | -0.0488 |
| far_m30_prior_swing_low | 97 | 0.30 | -324.56 | -0.0984 |
| near_m30_prior_swing_high | 18 | 2.23 | 62.64 | 0.1026 |
| near_m30_prior_swing_low | 18 | 0.24 | -51.73 | -0.0852 |

### Aggregate By Weekday

| weekday | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| Thu | 79 | 3.63 | 386.15 | 0.1446 |
| Wed | 66 | 0.21 | -300.92 | -0.1339 |
| Tue | 61 | 0.16 | -232.83 | -0.1132 |
| Fri | 51 | 0.09 | -256.83 | -0.1495 |
| Mon | 34 | 0.02 | -168.17 | -0.1471 |

### Acceptance Back Inside Box By Breakout Side

| breakout side | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| high_breakout | 129 | 0.00 | -715.09 | -0.1658 |
| low_breakout | 76 | 0.00 | -528.76 | -0.2051 |

### Acceptance Back Inside Box By Trigger

| trigger | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| exec_range_close_confirm | 75 | 0.00 | -415.28 | -0.1646 |
| exec_range_retest_confirm | 75 | 0.00 | -435.17 | -0.1726 |
| exec_breakout_bar_continuation | 55 | 0.00 | -393.40 | -0.2126 |

### Acceptance Back Inside Box By Box Width Bucket

| box width bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| wide | 205 | 0.00 | -1243.85 | -0.1804 |

### Acceptance Back Inside Box By Breakout Timing Bucket

| breakout timing bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| 60m_plus | 150 | 0.00 | -916.64 | -0.1815 |
| 0_30m | 48 | 0.00 | -293.93 | -0.1825 |
| 30_60m | 7 | 0.00 | -33.28 | -0.1412 |

## OOS

- aggregate trades: `88`
- aggregate PF: `0.62`
- aggregate net: `-121.67`
- avg failed-back-inside bars: `0.48`
- avg MFE before acceptance exit: `1.87`

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

### Aggregate By Breakout Side

| breakout side | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| high_breakout | 51 | 0.77 | -33.86 | -0.0186 |
| low_breakout | 37 | 0.48 | -87.81 | -0.0721 |

### Aggregate By Box Width Bucket

| box width bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| wide | 88 | 0.62 | -121.67 | -0.0411 |

### Aggregate By Breakout Strength Bucket

| breakout strength bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| strong_close | 75 | 0.93 | -13.49 | -0.0047 |
| medium_close | 9 | 0.07 | -55.36 | -0.1867 |
| weak_close | 4 | 0.00 | -52.82 | -0.3960 |

### Aggregate By Breakout Timing Bucket

| breakout timing bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| 60m_plus | 48 | 0.61 | -72.64 | -0.0453 |
| 30_60m | 21 | 0.23 | -66.96 | -0.0948 |
| 0_30m | 19 | 1.40 | 17.93 | 0.0291 |

### Aggregate By Previous Day Alignment

| prev-day alignment | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| far_prev_day_high | 42 | 0.91 | -10.30 | -0.0064 |
| far_prev_day_low | 37 | 0.48 | -87.81 | -0.0721 |
| unavailable | 9 | 0.15 | -23.56 | -0.0751 |

### Aggregate By M30 Prior Swing Alignment

| m30 swing alignment | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| far_m30_prior_swing_high | 51 | 0.77 | -33.86 | -0.0186 |
| far_m30_prior_swing_low | 37 | 0.48 | -87.81 | -0.0721 |

### Aggregate By Weekday

| weekday | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| Wed | 26 | 0.81 | -14.63 | -0.0181 |
| Fri | 25 | 0.41 | -53.15 | -0.0610 |
| Thu | 24 | 0.19 | -109.04 | -0.1354 |
| Tue | 13 | 4.76 | 55.15 | 0.1254 |

### Acceptance Back Inside Box By Breakout Side

| breakout side | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| low_breakout | 20 | 0.00 | -152.03 | -0.2283 |
| high_breakout | 13 | 0.00 | -119.52 | -0.2717 |

### Acceptance Back Inside Box By Trigger

| trigger | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| exec_breakout_bar_continuation | 13 | 0.00 | -149.80 | -0.3443 |
| exec_range_close_confirm | 10 | 0.00 | -58.99 | -0.1760 |
| exec_range_retest_confirm | 10 | 0.00 | -62.76 | -0.1862 |

### Acceptance Back Inside Box By Box Width Bucket

| box width bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| wide | 33 | 0.00 | -271.55 | -0.2454 |

### Acceptance Back Inside Box By Breakout Timing Bucket

| breakout timing bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| 60m_plus | 16 | 0.00 | -139.52 | -0.2614 |
| 30_60m | 12 | 0.00 | -87.36 | -0.2169 |
| 0_30m | 5 | 0.00 | -44.67 | -0.2622 |

## ACTUAL

- aggregate trades: `460`
- aggregate PF: `0.68`
- aggregate net: `-554.58`
- avg failed-back-inside bars: `0.85`
- avg MFE before acceptance exit: `1.83`

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

### Aggregate By Breakout Side

| breakout side | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| high_breakout | 273 | 0.86 | -137.17 | -0.0146 |
| low_breakout | 187 | 0.46 | -417.41 | -0.0657 |

### Aggregate By Box Width Bucket

| box width bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| wide | 460 | 0.68 | -554.58 | -0.0354 |

### Aggregate By Breakout Strength Bucket

| breakout strength bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| strong_close | 288 | 0.75 | -254.81 | -0.0254 |
| medium_close | 110 | 0.72 | -126.14 | -0.0348 |
| weak_close | 62 | 0.42 | -173.63 | -0.0829 |

### Aggregate By Breakout Timing Bucket

| breakout timing bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| 60m_plus | 301 | 0.58 | -535.06 | -0.0522 |
| 0_30m | 101 | 0.53 | -171.43 | -0.0496 |
| 30_60m | 58 | 2.27 | 151.91 | 0.0765 |

### Aggregate By Previous Day Alignment

| prev-day alignment | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| far_prev_day_high | 236 | 0.89 | -99.16 | -0.0122 |
| far_prev_day_low | 153 | 0.50 | -321.96 | -0.0620 |
| unavailable | 61 | 0.52 | -97.79 | -0.0469 |
| near_prev_day_low | 10 | 0.11 | -35.67 | -0.1050 |

### Aggregate By M30 Prior Swing Alignment

| m30 swing alignment | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| far_m30_prior_swing_high | 242 | 0.72 | -260.28 | -0.0314 |
| far_m30_prior_swing_low | 169 | 0.48 | -365.12 | -0.0636 |
| near_m30_prior_swing_high | 31 | 2.85 | 123.11 | 0.1168 |
| near_m30_prior_swing_low | 18 | 0.24 | -52.29 | -0.0852 |

### Aggregate By Weekday

| weekday | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| Thu | 121 | 2.10 | 323.58 | 0.0793 |
| Wed | 110 | 0.35 | -346.39 | -0.0925 |
| Tue | 92 | 0.77 | -69.69 | -0.0223 |
| Fri | 85 | 0.14 | -387.45 | -0.1349 |
| Mon | 52 | 0.58 | -74.63 | -0.0420 |

### Acceptance Back Inside Box By Breakout Side

| breakout side | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| high_breakout | 159 | 0.00 | -938.45 | -0.1758 |
| low_breakout | 105 | 0.00 | -759.73 | -0.2141 |

### Acceptance Back Inside Box By Trigger

| trigger | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| exec_range_retest_confirm | 96 | 0.00 | -569.39 | -0.1764 |
| exec_range_close_confirm | 94 | 0.00 | -532.83 | -0.1677 |
| exec_breakout_bar_continuation | 74 | 0.00 | -595.96 | -0.2396 |

### Acceptance Back Inside Box By Box Width Bucket

| box width bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| wide | 264 | 0.00 | -1698.18 | -0.1910 |

### Acceptance Back Inside Box By Breakout Timing Bucket

| breakout timing bucket | trades | pf | net | avg R |
|---|---:|---:|---:|---:|
| 60m_plus | 189 | 0.00 | -1225.40 | -0.1924 |
| 0_30m | 56 | 0.00 | -352.72 | -0.1869 |
| 30_60m | 19 | 0.00 | -120.06 | -0.1889 |
