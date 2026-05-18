# Strategy_01B Direction Filter Independent Validation - USDJPY

- Generated: 2026-05-14
- EA: `ExpectedValue_NWave_Scalper` / Strategy family: `Strategy_01_NWave_ExpectedValue`
- Scope: Strategy_01B diagnostic filters plus virtual-only `DirectionFilter`. No live-order behavior, entry pattern, or exit-management change.
- Test: `USDJPY M5`, `EnableTrading=false`, `H4/M15/M5`, `MaxManagedPositions=2`, fixed `1.5R`, `MinRR=1.2`, `FILTER_ALL`, conservative same-bar exit enabled.
- Important: Full, year, and quarter rows below are separate MT5 Strategy Tester executions, not calendar splits from one run.

## Full Window Direction Comparison
| Preset | Direction | Closed | Win% | ExpR | PF | MaxDD_R | MaxLosses | LongExpR | ShortExpR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | ANY | 801 | 42.70 | 0.0673 | 1.1175 | 23.0059 | 14 | -0.0709 | 0.1484 |
| C | LONG_ONLY | 296 | 37.16 | -0.0709 | 0.8872 | 29.9733 | 9 | -0.0709 | 0.0000 |
| C | SHORT_ONLY | 505 | 45.94 | 0.1484 | 1.2744 | 16.0048 | 14 | 0.0000 | 0.1484 |
| H | ANY | 633 | 42.50 | 0.0623 | 1.1084 | 20.0008 | 13 | -0.0569 | 0.1295 |
| H | LONG_ONLY | 229 | 37.55 | -0.0610 | 0.9023 | 31.9819 | 7 | -0.0610 | 0.0000 |
| H | SHORT_ONLY | 406 | 45.07 | 0.1267 | 1.2307 | 16.0024 | 13 | 0.0000 | 0.1267 |
| J | ANY | 532 | 43.42 | 0.0853 | 1.1508 | 21.4969 | 11 | -0.0233 | 0.1467 |
| J | LONG_ONLY | 193 | 38.86 | -0.0284 | 0.9535 | 26.9945 | 10 | -0.0284 | 0.0000 |
| J | SHORT_ONLY | 340 | 45.88 | 0.1467 | 1.2711 | 11.5070 | 10 | 0.0000 | 0.1467 |

## Promotion Criteria Check
| Preset | Direction | Trades | ExpR | PF | MaxDD_R | Years+ | Quarters+ | Full Exp/PF | Year Pass | Quarter Pass |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | ANY | 801 | 0.0673 | 1.1175 | 23.0059 | 2/3 | 5/9 | yes/yes | yes | no |
| C | LONG_ONLY | 296 | -0.0709 | 0.8872 | 29.9733 | 0/3 | 3/9 | no/no | no | no |
| C | SHORT_ONLY | 505 | 0.1484 | 1.2744 | 16.0048 | 3/3 | 9/9 | yes/yes | yes | yes |
| H | ANY | 633 | 0.0623 | 1.1084 | 20.0008 | 3/3 | 7/9 | yes/yes | yes | yes |
| H | LONG_ONLY | 229 | -0.0610 | 0.9023 | 31.9819 | 1/3 | 5/9 | no/no | no | no |
| H | SHORT_ONLY | 406 | 0.1267 | 1.2307 | 16.0024 | 3/3 | 7/9 | yes/yes | yes | yes |
| J | ANY | 532 | 0.0853 | 1.1508 | 21.4969 | 3/3 | 8/9 | yes/yes | yes | yes |
| J | LONG_ONLY | 193 | -0.0284 | 0.9535 | 26.9945 | 2/3 | 4/9 | no/no | yes | no |
| J | SHORT_ONLY | 340 | 0.1467 | 1.2711 | 11.5070 | 3/3 | 8/9 | yes/yes | yes | yes |

## Independent Year Metrics
| Preset | Direction | Year | Closed | Win% | ExpR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C | ANY | 2024 | 386 | 41.19 | 0.0297 | 1.0505 | 23.0059 |
| C | ANY | 2025 | 343 | 45.19 | 0.1297 | 1.2366 | 17.5135 |
| C | ANY | 2026Q1 | 71 | 39.44 | -0.0141 | 0.9767 | 10.4960 |
| C | LONG_ONLY | 2024 | 102 | 35.29 | -0.1175 | 0.8184 | 17.4919 |
| C | LONG_ONLY | 2025 | 173 | 39.31 | -0.0173 | 0.9715 | 20.9863 |
| C | LONG_ONLY | 2026Q1 | 21 | 28.57 | -0.2855 | 0.6003 | 6.9986 |
| C | SHORT_ONLY | 2024 | 284 | 43.31 | 0.0826 | 1.1457 | 16.0024 |
| C | SHORT_ONLY | 2025 | 170 | 51.18 | 0.2793 | 1.5720 | 16.0048 |
| C | SHORT_ONLY | 2026Q1 | 50 | 44.00 | 0.0999 | 1.1783 | 5.4976 |
| H | ANY | 2024 | 304 | 40.79 | 0.0197 | 1.0332 | 20.0008 |
| H | ANY | 2025 | 278 | 43.53 | 0.0881 | 1.1559 | 15.4954 |
| H | ANY | 2026Q1 | 50 | 48.00 | 0.2000 | 1.3846 | 4.4976 |
| H | LONG_ONLY | 2024 | 81 | 37.04 | -0.0739 | 0.8827 | 14.4959 |
| H | LONG_ONLY | 2025 | 138 | 37.68 | -0.0579 | 0.9070 | 24.9927 |
| H | LONG_ONLY | 2026Q1 | 10 | 40.00 | 0.0004 | 1.0006 | 3.0000 |
| H | SHORT_ONLY | 2024 | 223 | 42.15 | 0.0537 | 1.0928 | 16.0024 |
| H | SHORT_ONLY | 2025 | 142 | 48.59 | 0.2146 | 1.4175 | 15.5031 |
| H | SHORT_ONLY | 2026Q1 | 40 | 50.00 | 0.2499 | 1.4998 | 4.0000 |
| J | ANY | 2024 | 261 | 41.76 | 0.0438 | 1.0753 | 11.5070 |
| J | ANY | 2025 | 230 | 43.91 | 0.0977 | 1.1742 | 21.4969 |
| J | ANY | 2026Q1 | 40 | 52.50 | 0.3122 | 1.6573 | 4.0046 |
| J | LONG_ONLY | 2024 | 70 | 40.00 | 0.0002 | 1.0003 | 9.0010 |
| J | LONG_ONLY | 2025 | 114 | 36.84 | -0.0789 | 0.8750 | 26.9945 |
| J | LONG_ONLY | 2026Q1 | 9 | 55.56 | 0.3893 | 1.8759 | 3.0000 |
| J | SHORT_ONLY | 2024 | 191 | 42.41 | 0.0599 | 1.1039 | 11.5070 |
| J | SHORT_ONLY | 2025 | 117 | 50.43 | 0.2604 | 1.5254 | 10.0000 |
| J | SHORT_ONLY | 2026Q1 | 31 | 51.61 | 0.2898 | 1.5989 | 4.0046 |

## Independent Quarter Metrics
| Preset | Direction | Quarter | Closed | Win% | ExpR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C | ANY | 2024Q1 | 96 | 45.83 | 0.1457 | 1.2689 | 11.5065 |
| C | ANY | 2024Q2 | 110 | 42.73 | 0.0680 | 1.1188 | 16.0024 |
| C | ANY | 2024Q3 | 88 | 36.36 | -0.0910 | 0.8570 | 12.0045 |
| C | ANY | 2024Q4 | 92 | 39.13 | -0.0217 | 0.9643 | 10.4914 |
| C | ANY | 2025Q1 | 96 | 45.83 | 0.1458 | 1.2692 | 12.9909 |
| C | ANY | 2025Q2 | 80 | 45.00 | 0.1250 | 1.2272 | 7.4978 |
| C | ANY | 2025Q3 | 89 | 47.19 | 0.1796 | 1.3401 | 6.5047 |
| C | ANY | 2025Q4 | 75 | 40.00 | -0.0000 | 0.9999 | 16.0087 |
| C | ANY | 2026Q1 | 71 | 39.44 | -0.0141 | 0.9767 | 10.4960 |
| C | LONG_ONLY | 2024Q1 | 15 | 40.00 | 0.0003 | 1.0005 | 6.0000 |
| C | LONG_ONLY | 2024Q2 | 10 | 50.00 | 0.2508 | 1.5016 | 3.0000 |
| C | LONG_ONLY | 2024Q3 | 61 | 32.79 | -0.1803 | 0.7317 | 14.5023 |
| C | LONG_ONLY | 2024Q4 | 16 | 31.25 | -0.2187 | 0.6819 | 5.0000 |
| C | LONG_ONLY | 2025Q1 | 63 | 39.68 | -0.0077 | 0.9872 | 9.4923 |
| C | LONG_ONLY | 2025Q2 | 43 | 30.23 | -0.2441 | 0.6501 | 13.4954 |
| C | LONG_ONLY | 2025Q3 | 44 | 45.45 | 0.1364 | 1.2500 | 5.0019 |
| C | LONG_ONLY | 2025Q4 | 20 | 35.00 | -0.1253 | 0.8072 | 7.0000 |
| C | LONG_ONLY | 2026Q1 | 21 | 28.57 | -0.2855 | 0.6003 | 6.9986 |
| C | SHORT_ONLY | 2024Q1 | 81 | 46.91 | 0.1726 | 1.3251 | 11.5065 |
| C | SHORT_ONLY | 2024Q2 | 100 | 42.00 | 0.0498 | 1.0858 | 16.0024 |
| C | SHORT_ONLY | 2024Q3 | 27 | 44.44 | 0.1108 | 1.1995 | 3.5000 |
| C | SHORT_ONLY | 2024Q4 | 76 | 40.79 | 0.0198 | 1.0334 | 10.4914 |
| C | SHORT_ONLY | 2025Q1 | 33 | 57.58 | 0.4390 | 2.0348 | 5.5000 |
| C | SHORT_ONLY | 2025Q2 | 37 | 62.16 | 0.5540 | 2.4641 | 6.0000 |
| C | SHORT_ONLY | 2025Q3 | 45 | 48.89 | 0.2219 | 1.4342 | 6.0000 |
| C | SHORT_ONLY | 2025Q4 | 55 | 41.82 | 0.0455 | 1.0782 | 16.0000 |
| C | SHORT_ONLY | 2026Q1 | 50 | 44.00 | 0.0999 | 1.1783 | 5.4976 |
| H | ANY | 2024Q1 | 81 | 46.91 | 0.1727 | 1.3253 | 8.5000 |
| H | ANY | 2024Q2 | 81 | 39.51 | -0.0125 | 0.9793 | 16.0024 |
| H | ANY | 2024Q3 | 70 | 34.29 | -0.1428 | 0.7826 | 11.0015 |
| H | ANY | 2024Q4 | 72 | 41.67 | 0.0418 | 1.0716 | 5.5029 |
| H | ANY | 2025Q1 | 74 | 44.59 | 0.1148 | 1.2071 | 15.4951 |
| H | ANY | 2025Q2 | 67 | 40.30 | 0.0073 | 1.0123 | 9.0005 |
| H | ANY | 2025Q3 | 70 | 45.71 | 0.1428 | 1.2631 | 7.5047 |
| H | ANY | 2025Q4 | 65 | 41.54 | 0.0384 | 1.0657 | 13.0057 |
| H | ANY | 2026Q1 | 50 | 48.00 | 0.2000 | 1.3846 | 4.4976 |
| H | LONG_ONLY | 2024Q1 | 12 | 41.67 | 0.0417 | 1.0715 | 5.0000 |
| H | LONG_ONLY | 2024Q2 | 7 | 71.43 | 0.7869 | 3.7541 | 1.0000 |
| H | LONG_ONLY | 2024Q3 | 47 | 31.91 | -0.2020 | 0.7033 | 13.9993 |
| H | LONG_ONLY | 2024Q4 | 15 | 33.33 | -0.1665 | 0.7502 | 5.0000 |
| H | LONG_ONLY | 2025Q1 | 48 | 35.42 | -0.1144 | 0.8229 | 10.9964 |
| H | LONG_ONLY | 2025Q2 | 39 | 28.21 | -0.2949 | 0.5893 | 14.4976 |
| H | LONG_ONLY | 2025Q3 | 33 | 45.45 | 0.1364 | 1.2500 | 4.0019 |
| H | LONG_ONLY | 2025Q4 | 16 | 43.75 | 0.0933 | 1.1659 | 6.0000 |
| H | LONG_ONLY | 2026Q1 | 10 | 40.00 | 0.0004 | 1.0006 | 3.0000 |
| H | SHORT_ONLY | 2024Q1 | 69 | 47.83 | 0.1955 | 1.3746 | 8.5000 |
| H | SHORT_ONLY | 2024Q2 | 74 | 36.49 | -0.0881 | 0.8613 | 16.0024 |
| H | SHORT_ONLY | 2024Q3 | 23 | 39.13 | -0.0218 | 0.9641 | 4.5000 |
| H | SHORT_ONLY | 2024Q4 | 57 | 43.86 | 0.0966 | 1.1720 | 5.5029 |
| H | SHORT_ONLY | 2025Q1 | 26 | 61.54 | 0.5378 | 2.3983 | 5.0000 |
| H | SHORT_ONLY | 2025Q2 | 28 | 57.14 | 0.4283 | 1.9993 | 5.0000 |
| H | SHORT_ONLY | 2025Q3 | 38 | 44.74 | 0.1184 | 1.2142 | 6.0034 |
| H | SHORT_ONLY | 2025Q4 | 50 | 40.00 | 0.0001 | 1.0001 | 15.0000 |
| H | SHORT_ONLY | 2026Q1 | 40 | 50.00 | 0.2499 | 1.4998 | 4.0000 |
| J | ANY | 2024Q1 | 69 | 46.38 | 0.1589 | 1.2963 | 7.0000 |
| J | ANY | 2024Q2 | 68 | 41.18 | 0.0291 | 1.0494 | 11.5070 |
| J | ANY | 2024Q3 | 61 | 37.70 | -0.0573 | 0.9079 | 6.5015 |
| J | ANY | 2024Q4 | 63 | 41.27 | 0.0318 | 1.0542 | 6.4982 |
| J | ANY | 2025Q1 | 67 | 40.30 | 0.0074 | 1.0124 | 21.4969 |
| J | ANY | 2025Q2 | 58 | 41.38 | 0.0344 | 1.0586 | 8.4987 |
| J | ANY | 2025Q3 | 53 | 49.06 | 0.2262 | 1.4440 | 5.0047 |
| J | ANY | 2025Q4 | 50 | 44.00 | 0.0999 | 1.1784 | 10.5000 |
| J | ANY | 2026Q1 | 40 | 52.50 | 0.3122 | 1.6573 | 4.0046 |
| J | LONG_ONLY | 2024Q1 | 12 | 41.67 | 0.0417 | 1.0715 | 5.0000 |
| J | LONG_ONLY | 2024Q2 | 6 | 66.67 | 0.6676 | 3.0027 | 1.0000 |
| J | LONG_ONLY | 2024Q3 | 39 | 35.90 | -0.1025 | 0.8402 | 9.0010 |
| J | LONG_ONLY | 2024Q4 | 13 | 38.46 | -0.0383 | 0.9378 | 4.0000 |
| J | LONG_ONLY | 2025Q1 | 43 | 30.23 | -0.2440 | 0.6502 | 16.4969 |
| J | LONG_ONLY | 2025Q2 | 33 | 30.30 | -0.2424 | 0.6523 | 11.4998 |
| J | LONG_ONLY | 2025Q3 | 25 | 52.00 | 0.2998 | 1.6245 | 3.5000 |
| J | LONG_ONLY | 2025Q4 | 11 | 36.36 | -0.0912 | 0.8567 | 3.5072 |
| J | LONG_ONLY | 2026Q1 | 9 | 55.56 | 0.3893 | 1.8759 | 3.0000 |
| J | SHORT_ONLY | 2024Q1 | 57 | 47.37 | 0.1835 | 1.3487 | 7.0000 |
| J | SHORT_ONLY | 2024Q2 | 62 | 38.71 | -0.0327 | 0.9466 | 11.5070 |
| J | SHORT_ONLY | 2024Q3 | 22 | 40.91 | 0.0226 | 1.0383 | 4.0000 |
| J | SHORT_ONLY | 2024Q4 | 50 | 42.00 | 0.0500 | 1.0863 | 5.0000 |
| J | SHORT_ONLY | 2025Q1 | 24 | 58.33 | 0.4579 | 2.0989 | 5.0000 |
| J | SHORT_ONLY | 2025Q2 | 25 | 56.00 | 0.3996 | 1.9083 | 5.0000 |
| J | SHORT_ONLY | 2025Q3 | 28 | 46.43 | 0.1605 | 1.2996 | 5.0000 |
| J | SHORT_ONLY | 2025Q4 | 40 | 45.00 | 0.1249 | 1.2272 | 10.0000 |
| J | SHORT_ONLY | 2026Q1 | 31 | 51.61 | 0.2898 | 1.5989 | 4.0046 |

## Focus Candidate Readout
- C_ANY: 801 trades, expectancy 0.0673R, PF 1.1175, MaxDD 23.0059R, years 2/3, quarters 5/9.
- C_SHORT_ONLY: 505 trades, expectancy 0.1484R, PF 1.2744, MaxDD 16.0048R, years 3/3, quarters 9/9.
- H_ANY: 633 trades, expectancy 0.0623R, PF 1.1084, MaxDD 20.0008R, years 3/3, quarters 7/9.
- H_SHORT_ONLY: 406 trades, expectancy 0.1267R, PF 1.2307, MaxDD 16.0024R, years 3/3, quarters 7/9.
- J_ANY: 532 trades, expectancy 0.0853R, PF 1.1508, MaxDD 21.4969R, years 3/3, quarters 8/9.
- J_SHORT_ONLY: 340 trades, expectancy 0.1467R, PF 1.2711, MaxDD 11.5070R, years 3/3, quarters 8/9.

## Monthly ProfitR - Full Runs
| Month | C_ANY | C_SHORT_ONLY | H_ANY | H_SHORT_ONLY | J_ANY | J_SHORT_ONLY |
| --- | --- | --- | --- | --- | --- | --- |
| 2024-01 | 0.50 | -1.00 | 1.51 | 0.01 | 1.51 | 0.01 |
| 2024-02 | 12.01 | 9.50 | 8.51 | 7.50 | 7.49 | 6.49 |
| 2024-03 | 1.47 | 5.48 | 3.97 | 5.98 | 1.97 | 3.97 |
| 2024-04 | -12.01 | -12.01 | -13.51 | -13.51 | -9.01 | -9.01 |
| 2024-05 | 19.00 | 15.99 | 10.99 | 5.99 | 9.49 | 5.99 |
| 2024-06 | 0.49 | 0.99 | 1.50 | 1.00 | 1.49 | 0.99 |
| 2024-07 | -1.00 | 2.00 | -6.50 | -1.00 | -1.50 | -1.00 |
| 2024-08 | -4.01 | 3.00 | -3.00 | 3.00 | -2.50 | 3.00 |
| 2024-09 | -3.00 | -2.00 | -0.50 | -2.50 | 0.50 | -1.50 |
| 2024-10 | -7.49 | -7.49 | -1.49 | -1.49 | 1.50 | 1.50 |
| 2024-11 | 4.50 | 8.00 | 2.00 | 5.50 | 3.00 | 5.50 |
| 2024-12 | 0.99 | 0.99 | 2.50 | 1.49 | -2.50 | -4.50 |
| 2025-01 | 18.49 | 11.49 | 14.49 | 10.98 | 12.49 | 7.99 |
| 2025-02 | -2.49 | 0.00 | -3.99 | 0.00 | -9.49 | 0.00 |
| 2025-03 | -2.00 | 3.00 | -2.00 | 3.00 | -2.50 | 3.00 |
| 2025-04 | -6.00 | 1.50 | -5.50 | 1.50 | -2.50 | 1.50 |
| 2025-05 | 11.50 | 14.50 | 2.50 | 7.00 | 3.50 | 7.00 |
| 2025-06 | 9.00 | 4.50 | 6.49 | 3.50 | 4.00 | 1.50 |
| 2025-07 | -1.51 | -0.51 | -2.00 | -2.50 | 1.49 | 1.00 |
| 2025-08 | 15.49 | 10.99 | 11.00 | 7.99 | 11.99 | 5.00 |
| 2025-09 | 2.00 | -0.50 | 1.00 | -0.99 | -1.50 | -1.50 |
| 2025-10 | -11.01 | -9.50 | -6.51 | -9.50 | -5.50 | -4.50 |
| 2025-11 | 7.51 | 7.51 | 5.51 | 5.51 | 4.50 | 4.50 |
| 2025-12 | 2.50 | 3.50 | 2.50 | 3.00 | 4.99 | 4.00 |
| 2026-01 | -2.00 | 1.50 | 3.00 | 2.00 | 7.49 | 3.99 |
| 2026-02 | 0.00 | 2.50 | 1.00 | 2.00 | 4.00 | 4.00 |
| 2026-03 | 0.99 | 0.99 | 6.00 | 6.00 | 0.99 | 0.99 |

## Full Run RejectReason Counts
| RejectReason | C_ANY | C_SHORT_ONLY | H_ANY | H_SHORT_ONLY | J_ANY | J_SHORT_ONLY |
| --- | --- | --- | --- | --- | --- | --- |
| break_candle_strength_filter_failed | 0 | 0 | 0 | 0 | 368 | 231 |
| consecutive_loss_blocked | 39 | 18 | 22 | 9 | 8 | 4 |
| direction_filter_failed | 0 | 4141 | 0 | 4141 | 0 | 4141 |
| entry_open_count_filter_failed | 0 | 0 | 544 | 320 | 321 | 183 |
| fibo_filter_failed | 184 | 184 | 184 | 184 | 184 | 184 |
| max_positions_blocked | 122 | 65 | 0 | 0 | 0 | 0 |
| pattern_adx_bucket_filter_failed | 1646 | 1032 | 1646 | 1032 | 1646 | 1032 |
| rr_too_low | 1 | 1 | 1 | 1 | 1 | 1 |
| spread_too_wide | 62 | 46 | 47 | 39 | 27 | 21 |
| trend_alignment_filter_failed | 5314 | 2274 | 5314 | 2274 | 5314 | 2274 |

## Readout
- ShortOnly improves expectancy and drawdown profile for all C/H/J full-window tests versus Any direction.
- LongOnly remains weak or negative in the full window. Small positive quarter slices exist, but the full-window and year-level evidence does not support retaining long exposure as-is.
- Preset J ShortOnly is the cleanest strict candidate: `340` full-window trades, `+0.1467R`, PF `1.2711`, MaxDD `11.5070R`, positive years `3/3`, positive quarters `8/9`.
- Preset H ShortOnly is broader than J ShortOnly and also passes: `406` trades, `+0.1267R`, PF `1.2307`, MaxDD `16.0024R`, positive years `3/3`, positive quarters `7/9`.
- Preset C ShortOnly has the largest ShortOnly sample and strongest broad result: `505` trades, `+0.1484R`, PF `1.2744`, MaxDD `16.0048R`, positive years `3/3`, positive quarters `9/9`. Its broader entry stream should be reviewed against month clustering before choosing it over J.
- No demo/live promotion is made here. This remains virtual-validation evidence for a possible Strategy_01B ShortOnly branch.

## Artifacts
| Artifact | Path |
| --- | --- |
| Run manifest | [manifest.csv](./manifest.csv) |
| Run metrics | [run_metrics.csv](./run_metrics.csv) |
| Full metrics | [full_metrics.csv](./full_metrics.csv) |
| Year metrics | [year_metrics.csv](./year_metrics.csv) |
| Quarter metrics | [quarter_metrics.csv](./quarter_metrics.csv) |
| Promotion check | [promotion_check.csv](./promotion_check.csv) |
| Reject counts by run | [reject_counts_by_run.csv](./reject_counts_by_run.csv) |
| Monthly ProfitR from full runs | [monthly_profit_r_full_runs.csv](./monthly_profit_r_full_runs.csv) |
| Raw summary CSVs | [raw_summaries/](./raw_summaries/) |
