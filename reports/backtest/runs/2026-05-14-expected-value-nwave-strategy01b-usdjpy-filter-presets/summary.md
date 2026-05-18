# Strategy_01B Filter Preset Validation - USDJPY

- Generated: 2026-05-14
- EA: `ExpectedValue_NWave_Scalper` / Strategy family: `Strategy_01_NWave_ExpectedValue`
- Scope: existing Strategy_01 entries filtered by existing diagnostic tags only. No new entry pattern, no BE/partial/trailing promotion, and no live-order behavior change.
- Test: `USDJPY M5`, `2024.01.01` to `2026.03.30`, `EnableTrading=false`, `H4/M15/M5`, `MaxManagedPositions=2`, fixed `1.5R`, `MinRR=1.2`, `FILTER_ALL`, conservative same-bar exit enabled.
- Year/quarter/month tables are calendar splits from each full-window filtered run. They are not separate MT5 reruns.

## Presets
| Preset | Filters |
| --- | --- |
| C | CounterTrend + PatternADXBucket=middle |
| H | CounterTrend + PatternADXBucket=middle + EntryOpenCount<=0 |
| J | CounterTrend + PatternADXBucket=middle + BreakStrength=high + EntryOpenCount<=0 |

## Full Window Metrics
| Preset | Closed | Win% | AvgWinR | AvgLossR | ExpectancyR | PF | MaxDD_R | MaxLosses | LongExpR | ShortExpR | Positive Q |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | 801 | 42.70 | 1.4998 | -1.0000 | 0.0673 | 1.1175 | 23.0059 | 14 | -0.0709 | 0.1484 | 5/9 |
| H | 633 | 42.50 | 1.4999 | -1.0000 | 0.0623 | 1.1084 | 20.0008 | 13 | -0.0569 | 0.1295 | 7/9 |
| J | 532 | 43.42 | 1.4996 | -1.0000 | 0.0853 | 1.1508 | 21.4969 | 11 | -0.0233 | 0.1467 | 8/9 |

## Promotion Criteria Check
| Preset | Full Exp/PF Pass | Positive Years | Positive Quarters | Trades | MaxDD_R |
| --- | --- | --- | --- | --- | --- |
| C | yes | 2/3 | 5/9 | 801 | 23.0059 |
| H | yes | 3/3 | 7/9 | 633 | 20.0008 |
| J | yes | 3/3 | 8/9 | 532 | 21.4969 |

## Year Metrics
| Preset | Year | Closed | Win% | ExpectancyR | PF | MaxDD_R | MaxLosses |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C | 2024 | 386 | 41.19 | 0.0297 | 1.0505 | 23.0059 | 11 |
| C | 2025 | 344 | 45.06 | 0.1264 | 1.2301 | 17.5135 | 14 |
| C | 2026 | 71 | 39.44 | -0.0141 | 0.9767 | 10.4960 | 5 |
| H | 2024 | 304 | 40.79 | 0.0197 | 1.0332 | 20.0008 | 11 |
| H | 2025 | 279 | 43.37 | 0.0842 | 1.1486 | 15.4954 | 13 |
| H | 2026 | 50 | 48.00 | 0.2000 | 1.3846 | 4.4976 | 4 |
| J | 2024 | 261 | 41.76 | 0.0438 | 1.0753 | 11.5070 | 8 |
| J | 2025 | 231 | 43.72 | 0.0930 | 1.1652 | 21.4969 | 11 |
| J | 2026 | 40 | 52.50 | 0.3122 | 1.6573 | 4.0046 | 4 |

## Quarter Metrics
| Preset | Quarter | Closed | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| C | 2024Q1 | 96 | 45.83 | 0.1457 | 1.2689 | 11.5065 |
| C | 2024Q2 | 110 | 42.73 | 0.0680 | 1.1188 | 16.0024 |
| C | 2024Q3 | 88 | 36.36 | -0.0910 | 0.8570 | 12.0045 |
| C | 2024Q4 | 92 | 39.13 | -0.0217 | 0.9643 | 10.4914 |
| C | 2025Q1 | 96 | 45.83 | 0.1458 | 1.2692 | 12.9909 |
| C | 2025Q2 | 83 | 46.99 | 0.1747 | 1.3296 | 7.4978 |
| C | 2025Q3 | 89 | 47.19 | 0.1796 | 1.3401 | 6.5047 |
| C | 2025Q4 | 76 | 39.47 | -0.0132 | 0.9782 | 16.0087 |
| C | 2026Q1 | 71 | 39.44 | -0.0141 | 0.9767 | 10.4960 |
| H | 2024Q1 | 81 | 46.91 | 0.1727 | 1.3253 | 8.5000 |
| H | 2024Q2 | 81 | 39.51 | -0.0125 | 0.9793 | 16.0024 |
| H | 2024Q3 | 70 | 34.29 | -0.1428 | 0.7826 | 11.0015 |
| H | 2024Q4 | 72 | 41.67 | 0.0418 | 1.0716 | 5.5029 |
| H | 2025Q1 | 74 | 44.59 | 0.1148 | 1.2071 | 15.4951 |
| H | 2025Q2 | 69 | 42.03 | 0.0506 | 1.0873 | 9.0005 |
| H | 2025Q3 | 70 | 45.71 | 0.1428 | 1.2631 | 7.5047 |
| H | 2025Q4 | 66 | 40.91 | 0.0227 | 1.0384 | 13.0057 |
| H | 2026Q1 | 50 | 48.00 | 0.2000 | 1.3846 | 4.4976 |
| J | 2024Q1 | 69 | 46.38 | 0.1589 | 1.2963 | 7.0000 |
| J | 2024Q2 | 68 | 41.18 | 0.0291 | 1.0494 | 11.5070 |
| J | 2024Q3 | 61 | 37.70 | -0.0573 | 0.9079 | 6.5015 |
| J | 2024Q4 | 63 | 41.27 | 0.0318 | 1.0542 | 6.4982 |
| J | 2025Q1 | 67 | 40.30 | 0.0074 | 1.0124 | 21.4969 |
| J | 2025Q2 | 60 | 43.33 | 0.0833 | 1.1469 | 8.4987 |
| J | 2025Q3 | 53 | 49.06 | 0.2262 | 1.4440 | 5.0047 |
| J | 2025Q4 | 51 | 43.14 | 0.0783 | 1.1377 | 10.5000 |
| J | 2026Q1 | 40 | 52.50 | 0.3122 | 1.6573 | 4.0046 |

## Session Metrics
| Preset | Session | Closed | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| C | asia | 248 | 43.15 | 0.0785 | 1.1380 | 13.0165 |
| C | late_us | 47 | 42.55 | 0.0631 | 1.1099 | 10.0058 |
| C | london | 220 | 41.36 | 0.0342 | 1.0584 | 18.5010 |
| C | new_york | 286 | 43.36 | 0.0838 | 1.1480 | 16.4978 |
| H | asia | 192 | 44.27 | 0.1067 | 1.1914 | 10.9983 |
| H | late_us | 41 | 43.90 | 0.0970 | 1.1729 | 7.4945 |
| H | london | 160 | 41.25 | 0.0314 | 1.0534 | 20.5024 |
| H | new_york | 240 | 41.67 | 0.0416 | 1.0713 | 17.4978 |
| J | asia | 169 | 46.75 | 0.1684 | 1.3162 | 8.0000 |
| J | late_us | 36 | 50.00 | 0.2495 | 1.4990 | 4.0000 |
| J | london | 126 | 43.65 | 0.0913 | 1.1620 | 13.0112 |
| J | new_york | 201 | 39.30 | -0.0176 | 0.9710 | 21.9987 |

## Direction Metrics
| Preset | Direction | Closed | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| C | LONG | 296 | 37.16 | -0.0709 | 0.8872 | 29.9733 |
| C | SHORT | 505 | 45.94 | 0.1484 | 1.2744 | 16.0048 |
| H | LONG | 228 | 37.72 | -0.0569 | 0.9086 | 31.9819 |
| H | SHORT | 405 | 45.19 | 0.1295 | 1.2362 | 16.0024 |
| J | LONG | 192 | 39.06 | -0.0233 | 0.9617 | 26.9945 |
| J | SHORT | 340 | 45.88 | 0.1467 | 1.2711 | 11.5070 |

## RejectReason Counts
| Preset | RejectReason | Count |
| --- | --- | --- |
| C | consecutive_loss_blocked | 39 |
| C | fibo_filter_failed | 184 |
| C | max_positions_blocked | 122 |
| C | pattern_adx_bucket_filter_failed | 1646 |
| C | rr_too_low | 1 |
| C | spread_too_wide | 62 |
| C | trend_alignment_filter_failed | 5314 |
| H | consecutive_loss_blocked | 22 |
| H | entry_open_count_filter_failed | 544 |
| H | fibo_filter_failed | 184 |
| H | pattern_adx_bucket_filter_failed | 1646 |
| H | rr_too_low | 1 |
| H | spread_too_wide | 47 |
| H | trend_alignment_filter_failed | 5314 |
| J | break_candle_strength_filter_failed | 368 |
| J | consecutive_loss_blocked | 8 |
| J | entry_open_count_filter_failed | 321 |
| J | fibo_filter_failed | 184 |
| J | pattern_adx_bucket_filter_failed | 1646 |
| J | rr_too_low | 1 |
| J | spread_too_wide | 27 |
| J | trend_alignment_filter_failed | 5314 |

## Monthly ProfitR
Preset C:
| Month | Trades | ProfitR | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| 2024-01 | 32 | 0.5004 | 0.0156 | 1.0263 |
| 2024-02 | 38 | 12.0092 | 0.3160 | 1.6672 |
| 2024-03 | 26 | 1.4748 | 0.0567 | 1.0983 |
| 2024-04 | 37 | -12.0062 | -0.3245 | 0.5553 |
| 2024-05 | 41 | 18.9963 | 0.4633 | 2.1174 |
| 2024-06 | 32 | 0.4931 | 0.0154 | 1.0260 |
| 2024-07 | 31 | -1.0011 | -0.0323 | 0.9473 |
| 2024-08 | 29 | -4.0062 | -0.1381 | 0.7891 |
| 2024-09 | 28 | -2.9992 | -0.1071 | 0.8334 |
| 2024-10 | 40 | -7.4914 | -0.1873 | 0.7225 |
| 2024-11 | 23 | 4.4995 | 0.1956 | 1.3750 |
| 2024-12 | 29 | 0.9948 | 0.0343 | 1.0585 |
| 2025-01 | 34 | 18.4901 | 0.5438 | 2.4223 |
| 2025-02 | 30 | -2.4900 | -0.0830 | 0.8689 |
| 2025-03 | 32 | -1.9996 | -0.0625 | 0.9000 |
| 2025-04 | 26 | -5.9997 | -0.2308 | 0.6667 |
| 2025-05 | 28 | 9.5005 | 0.3393 | 1.7308 |
| 2025-06 | 29 | 10.9995 | 0.3793 | 1.8461 |
| 2025-07 | 34 | -1.5068 | -0.0443 | 0.9282 |
| 2025-08 | 32 | 15.4914 | 0.4841 | 2.1916 |
| 2025-09 | 23 | 2.0019 | 0.0870 | 1.1540 |
| 2025-10 | 31 | -11.0087 | -0.3551 | 0.5214 |
| 2025-11 | 25 | 7.5052 | 0.3002 | 1.6254 |
| 2025-12 | 20 | 2.5006 | 0.1250 | 1.2273 |
| 2026-01 | 27 | -1.9998 | -0.0741 | 0.8824 |
| 2026-02 | 20 | 0.0025 | 0.0001 | 1.0002 |
| 2026-03 | 24 | 0.9948 | 0.0414 | 1.0711 |

Preset H:
| Month | Trades | ProfitR | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| 2024-01 | 26 | 1.5069 | 0.0580 | 1.1005 |
| 2024-02 | 34 | 8.5054 | 0.2502 | 1.5003 |
| 2024-03 | 21 | 3.9748 | 0.1893 | 1.3613 |
| 2024-04 | 31 | -13.5062 | -0.4357 | 0.4372 |
| 2024-05 | 29 | 10.9935 | 0.3791 | 1.8457 |
| 2024-06 | 21 | 1.5003 | 0.0714 | 1.1250 |
| 2024-07 | 24 | -6.4983 | -0.2708 | 0.6177 |
| 2024-08 | 23 | -3.0032 | -0.1306 | 0.7998 |
| 2024-09 | 23 | -0.4967 | -0.0216 | 0.9645 |
| 2024-10 | 29 | -1.4916 | -0.0514 | 0.9171 |
| 2024-11 | 18 | 2.0013 | 0.1112 | 1.2001 |
| 2024-12 | 25 | 2.4967 | 0.0999 | 1.1783 |
| 2025-01 | 28 | 14.4864 | 0.5174 | 2.3169 |
| 2025-02 | 24 | -3.9942 | -0.1664 | 0.7504 |
| 2025-03 | 22 | -1.9996 | -0.0909 | 0.8572 |
| 2025-04 | 23 | -5.4997 | -0.2391 | 0.6563 |
| 2025-05 | 21 | 1.4982 | 0.0713 | 1.1249 |
| 2025-06 | 25 | 7.4938 | 0.2998 | 1.6245 |
| 2025-07 | 27 | -2.0035 | -0.0742 | 0.8821 |
| 2025-08 | 24 | 10.9985 | 0.4583 | 2.0999 |
| 2025-09 | 19 | 1.0036 | 0.0528 | 1.0912 |
| 2025-10 | 29 | -6.5062 | -0.2244 | 0.6747 |
| 2025-11 | 22 | 5.5052 | 0.2502 | 1.5005 |
| 2025-12 | 15 | 2.4973 | 0.1665 | 1.3122 |
| 2026-01 | 17 | 3.0002 | 0.1765 | 1.3334 |
| 2026-02 | 14 | 1.0006 | 0.0715 | 1.1251 |
| 2026-03 | 19 | 6.0000 | 0.3158 | 1.6667 |

Preset J:
| Month | Trades | ProfitR | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| 2024-01 | 21 | 1.5069 | 0.0718 | 1.1256 |
| 2024-02 | 30 | 7.4867 | 0.2496 | 1.4991 |
| 2024-03 | 18 | 1.9686 | 0.1094 | 1.1969 |
| 2024-04 | 24 | -9.0062 | -0.3753 | 0.4997 |
| 2024-05 | 23 | 9.4906 | 0.4126 | 1.9491 |
| 2024-06 | 21 | 1.4911 | 0.0710 | 1.1243 |
| 2024-07 | 19 | -1.4983 | -0.0789 | 0.8751 |
| 2024-08 | 20 | -2.5025 | -0.1251 | 0.8075 |
| 2024-09 | 22 | 0.5026 | 0.0228 | 1.0387 |
| 2024-10 | 26 | 1.5031 | 0.0578 | 1.1002 |
| 2024-11 | 17 | 2.9970 | 0.1763 | 1.3330 |
| 2024-12 | 20 | -2.4957 | -0.1248 | 0.8080 |
| 2025-01 | 25 | 12.4916 | 0.4997 | 2.2492 |
| 2025-02 | 22 | -9.4946 | -0.4316 | 0.4415 |
| 2025-03 | 20 | -2.5010 | -0.1250 | 0.8076 |
| 2025-04 | 20 | -2.4997 | -0.1250 | 0.8077 |
| 2025-05 | 20 | 2.4982 | 0.1249 | 1.2271 |
| 2025-06 | 20 | 4.9967 | 0.2498 | 1.4997 |
| 2025-07 | 21 | 1.4941 | 0.0711 | 1.1245 |
| 2025-08 | 18 | 11.9932 | 0.6663 | 2.9989 |
| 2025-09 | 14 | -1.4999 | -0.1071 | 0.8333 |
| 2025-10 | 23 | -5.4975 | -0.2390 | 0.6564 |
| 2025-11 | 18 | 4.4993 | 0.2500 | 1.4999 |
| 2025-12 | 10 | 4.9928 | 0.4993 | 2.2482 |
| 2026-01 | 15 | 7.4923 | 0.4995 | 2.2487 |
| 2026-02 | 11 | 4.0006 | 0.3637 | 1.8001 |
| 2026-03 | 14 | 0.9950 | 0.0711 | 1.1244 |

## Artifacts
| Artifact | Path |
| --- | --- |
| Preset C diagnostics | [preset_c/diagnostics.csv](./preset_c/diagnostics.csv) |
| Preset H diagnostics | [preset_h/diagnostics.csv](./preset_h/diagnostics.csv) |
| Preset J diagnostics | [preset_j/diagnostics.csv](./preset_j/diagnostics.csv) |
| Main metrics | [preset_main_metrics.csv](./preset_main_metrics.csv) |
| Year metrics | [year_metrics.csv](./year_metrics.csv) |
| Quarter metrics | [quarter_metrics.csv](./quarter_metrics.csv) |
| Monthly ProfitR | [monthly_profit_r.csv](./monthly_profit_r.csv) |
| Reject counts | [reject_counts.csv](./reject_counts.csv) |

## Readout
- Preset C: 801 trades, expectancy 0.0673R, PF 1.1175, MaxDD 23.0059R, positive quarters 5/9.
- Preset H: 633 trades, expectancy 0.0623R, PF 1.1084, MaxDD 20.0008R, positive quarters 7/9.
- Preset J: 532 trades, expectancy 0.0853R, PF 1.1508, MaxDD 21.4969R, positive quarters 8/9.
- Preset C is the broad candidate and has the largest trade count. Preset J is the stricter candidate and has the highest full-window expectancy, but lower sample size.
- EURUSD and XAUUSD reference runs were attempted after the USDJPY validation, but no complete summary CSV was produced within the per-run timeout. They are omitted from this report and should not be used as evidence.
- This is still a validation result, not a live/demo promotion. Separate period reruns and successful cross-symbol reference checks are still needed before any promotion.
