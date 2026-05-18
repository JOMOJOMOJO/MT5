# Baseline-B Expanded Validation

- Generated: 2026-05-14
- EA: `ExpectedValue_NWave_Scalper` / Strategy: `Strategy_01_NWave_ExpectedValue`
- Baseline-B: `EnableTrading=false`, `H4/M15/M5`, `MaxManagedPositions=2`, `TakeProfitRMultiple=1.5`, `MinRR=1.2`, `FILTER_ALL`, conservative same-bar exit enabled.
- Note: EURUSD and XAUUSD tester logs include real-tick mismatch/absence warnings; results are recorded as produced and should be treated as first-pass cross-symbol evidence, not final broker-quality proof.

## Run Status
| Run | Symbol | From | To | Diagnostics CSV | Summary CSV | HTML |
| --- | --- | --- | --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | USDJPY | 2024.01.01 | 2026.03.30 | yes | yes | yes |
| baseline-b-usdjpy-2024 | USDJPY | 2024.01.01 | 2024.12.31 | yes | yes | yes |
| baseline-b-usdjpy-2025 | USDJPY | 2025.01.01 | 2025.12.31 | yes | yes | yes |
| baseline-b-usdjpy-2026q1 | USDJPY | 2026.01.01 | 2026.03.30 | yes | yes | yes |
| baseline-b-usdjpy-2024q1 | USDJPY | 2024.01.01 | 2024.03.31 | yes | yes | yes |
| baseline-b-usdjpy-2024q2 | USDJPY | 2024.04.01 | 2024.06.30 | yes | yes | yes |
| baseline-b-usdjpy-2024q3 | USDJPY | 2024.07.01 | 2024.09.30 | yes | yes | yes |
| baseline-b-usdjpy-2024q4 | USDJPY | 2024.10.01 | 2024.12.31 | yes | yes | yes |
| baseline-b-usdjpy-2025q1 | USDJPY | 2025.01.01 | 2025.03.31 | yes | yes | yes |
| baseline-b-usdjpy-2025q2 | USDJPY | 2025.04.01 | 2025.06.30 | yes | yes | yes |
| baseline-b-usdjpy-2025q3 | USDJPY | 2025.07.01 | 2025.09.30 | yes | yes | yes |
| baseline-b-usdjpy-2025q4 | USDJPY | 2025.10.01 | 2025.12.31 | yes | yes | yes |
| baseline-b-usdjpy-2026q1-quarter | USDJPY | 2026.01.01 | 2026.03.30 | yes | yes | yes |
| baseline-b-eurusd-full-2024-2026q1 | EURUSD | 2024.01.01 | 2026.03.30 | yes | yes | yes |
| baseline-b-xauusd-full-2024-2026q1 | XAUUSD | 2024.01.01 | 2026.03.30 | yes | yes | yes |

## Main R Metrics
| Run | Symbol | From | To | Closed | Win% | AvgWinR | AvgLossR | ExpectancyR | PF | MaxLosses | MaxDD_R | LongExpR | ShortExpR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | USDJPY | 2024.01.01 | 2026.03.30 | 2848 | 38.52 | 1.5000 | -1.0000 | -0.0371 | 0.9397 | 12 | 141.0338 | -0.0378 | -0.0363 |
| baseline-b-usdjpy-2024 | USDJPY | 2024.01.01 | 2024.12.31 | 1199 | 39.20 | 1.5000 | -1.0000 | -0.0200 | 0.9671 | 11 | 43.0142 | 0.0182 | -0.0595 |
| baseline-b-usdjpy-2025 | USDJPY | 2025.01.01 | 2025.12.31 | 1322 | 36.99 | 1.4999 | -1.0000 | -0.0753 | 0.8805 | 12 | 107.0638 | -0.1200 | -0.0305 |
| baseline-b-usdjpy-2026q1 | USDJPY | 2026.01.01 | 2026.03.30 | 316 | 41.46 | 1.5000 | -1.0000 | 0.0364 | 1.0622 | 9 | 13.0013 | 0.0602 | 0.0126 |
| baseline-b-usdjpy-2024q1 | USDJPY | 2024.01.01 | 2024.03.31 | 318 | 38.05 | 1.5000 | -1.0000 | -0.0487 | 0.9213 | 11 | 27.5030 | -0.0098 | -0.0831 |
| baseline-b-usdjpy-2024q2 | USDJPY | 2024.04.01 | 2024.06.30 | 285 | 42.11 | 1.5000 | -1.0000 | 0.0526 | 1.0909 | 6 | 19.4927 | 0.1931 | -0.1101 |
| baseline-b-usdjpy-2024q3 | USDJPY | 2024.07.01 | 2024.09.30 | 319 | 39.81 | 1.5000 | -1.0000 | -0.0047 | 0.9922 | 7 | 15.0108 | -0.0773 | 0.0760 |
| baseline-b-usdjpy-2024q4 | USDJPY | 2024.10.01 | 2024.12.31 | 271 | 36.16 | 1.5001 | -1.0000 | -0.0959 | 0.8498 | 10 | 38.9945 | -0.0556 | -0.1359 |
| baseline-b-usdjpy-2025q1 | USDJPY | 2025.01.01 | 2025.03.31 | 344 | 37.21 | 1.4998 | -1.0000 | -0.0698 | 0.8888 | 9 | 33.5269 | -0.1149 | -0.0302 |
| baseline-b-usdjpy-2025q2 | USDJPY | 2025.04.01 | 2025.06.30 | 328 | 37.50 | 1.4997 | -1.0000 | -0.0626 | 0.8998 | 9 | 38.5365 | -0.1082 | -0.0208 |
| baseline-b-usdjpy-2025q3 | USDJPY | 2025.07.01 | 2025.09.30 | 318 | 37.11 | 1.4998 | -1.0000 | -0.0724 | 0.8849 | 12 | 46.0213 | -0.0992 | -0.0449 |
| baseline-b-usdjpy-2025q4 | USDJPY | 2025.10.01 | 2025.12.31 | 313 | 35.78 | 1.5003 | -1.0000 | -0.1053 | 0.8360 | 9 | 43.4836 | -0.1327 | -0.0715 |
| baseline-b-usdjpy-2026q1-quarter | USDJPY | 2026.01.01 | 2026.03.30 | 316 | 41.46 | 1.5000 | -1.0000 | 0.0364 | 1.0622 | 9 | 13.0013 | 0.0602 | 0.0126 |
| baseline-b-eurusd-full-2024-2026q1 | EURUSD | 2024.01.01 | 2026.03.30 | 2716 | 33.36 | 1.5002 | -1.0000 | -0.1660 | 0.7510 | 16 | 468.2744 | -0.2327 | -0.0907 |
| baseline-b-xauusd-full-2024-2026q1 | XAUUSD | 2024.01.01 | 2026.03.30 | 3088 | 39.12 | 1.5000 | -1.0000 | -0.0220 | 0.9638 | 17 | 138.5077 | 0.0397 | -0.0824 |

## USDJPY Stability Slice
| Run | Closed | Win% | ExpectancyR | PF | MaxDD_R | LongExpR | ShortExpR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | 2848 | 38.52 | -0.0371 | 0.9397 | 141.0338 | -0.0378 | -0.0363 |
| baseline-b-usdjpy-2024 | 1199 | 39.20 | -0.0200 | 0.9671 | 43.0142 | 0.0182 | -0.0595 |
| baseline-b-usdjpy-2025 | 1322 | 36.99 | -0.0753 | 0.8805 | 107.0638 | -0.1200 | -0.0305 |
| baseline-b-usdjpy-2026q1 | 316 | 41.46 | 0.0364 | 1.0622 | 13.0013 | 0.0602 | 0.0126 |
| baseline-b-usdjpy-2024q1 | 318 | 38.05 | -0.0487 | 0.9213 | 27.5030 | -0.0098 | -0.0831 |
| baseline-b-usdjpy-2024q2 | 285 | 42.11 | 0.0526 | 1.0909 | 19.4927 | 0.1931 | -0.1101 |
| baseline-b-usdjpy-2024q3 | 319 | 39.81 | -0.0047 | 0.9922 | 15.0108 | -0.0773 | 0.0760 |
| baseline-b-usdjpy-2024q4 | 271 | 36.16 | -0.0959 | 0.8498 | 38.9945 | -0.0556 | -0.1359 |
| baseline-b-usdjpy-2025q1 | 344 | 37.21 | -0.0698 | 0.8888 | 33.5269 | -0.1149 | -0.0302 |
| baseline-b-usdjpy-2025q2 | 328 | 37.50 | -0.0626 | 0.8998 | 38.5365 | -0.1082 | -0.0208 |
| baseline-b-usdjpy-2025q3 | 318 | 37.11 | -0.0724 | 0.8849 | 46.0213 | -0.0992 | -0.0449 |
| baseline-b-usdjpy-2025q4 | 313 | 35.78 | -0.1053 | 0.8360 | 43.4836 | -0.1327 | -0.0715 |
| baseline-b-usdjpy-2026q1-quarter | 316 | 41.46 | 0.0364 | 1.0622 | 13.0013 | 0.0602 | 0.0126 |

## Session ExpectancyR
| Run | asia | london | new_york | late_us |
| --- | --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | 0.0060 (1081) | -0.0685 (765) | -0.0506 (890) | -0.1297 (112) |
| baseline-b-usdjpy-2024 | -0.0617 (437) | -0.0407 (331) | 0.0584 (385) | -0.1310 (46) |
| baseline-b-usdjpy-2025 | 0.0284 (525) | -0.1002 (339) | -0.1853 (402) | -0.1072 (56) |
| baseline-b-usdjpy-2026q1 | 0.1206 (116) | -0.0658 (91) | 0.0499 (100) | -0.1668 (9) |
| baseline-b-usdjpy-2024q1 | -0.0042 (118) | -0.0852 (82) | -0.0305 (98) | -0.2517 (20) |
| baseline-b-usdjpy-2024q2 | -0.0907 (110) | 0.0002 (85) | 0.3287 (79) | -0.0905 (11) |
| baseline-b-usdjpy-2024q3 | -0.0315 (111) | -0.0625 (88) | 0.0453 (110) | 0.2502 (10) |
| baseline-b-usdjpy-2024q4 | -0.1161 (99) | -0.0625 (72) | -0.0789 (95) | -0.4992 (5) |
| baseline-b-usdjpy-2025q1 | -0.0106 (144) | -0.0432 (81) | -0.1971 (109) | 0.2495 (10) |
| baseline-b-usdjpy-2025q2 | 0.0553 (135) | -0.1758 (91) | -0.0884 (85) | -0.2645 (17) |
| baseline-b-usdjpy-2025q3 | 0.0199 (125) | -0.1884 (77) | -0.0751 (100) | -0.2185 (16) |
| baseline-b-usdjpy-2025q4 | 0.0380 (118) | -0.0120 (81) | -0.3562 (101) | -0.0388 (13) |
| baseline-b-usdjpy-2026q1-quarter | 0.1206 (116) | -0.0658 (91) | 0.0499 (100) | -0.1668 (9) |
| baseline-b-eurusd-full-2024-2026q1 | -0.2573 (956) | -0.1264 (830) | -0.0855 (842) | -0.3176 (88) |
| baseline-b-xauusd-full-2024-2026q1 | -0.0304 (1070) | 0.0085 (828) | -0.0383 (1058) | -0.0152 (132) |

## Direction x Session ExpectancyR
| Run | L_asia | L_london | L_new_york | L_late_us | S_asia | S_london | S_new_york | S_late_us |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | -0.0017 (561) | -0.0505 (374) | -0.0283 (440) | -0.3547 (62) | 0.0142 (520) | -0.0857 (391) | -0.0724 (450) | 0.1492 (50) |
| baseline-b-usdjpy-2024 | 0.0779 (225) | 0.0034 (162) | 0.0309 (194) | -0.4638 (28) | -0.2099 (212) | -0.0829 (169) | 0.0862 (191) | 0.3868 (18) |
| baseline-b-usdjpy-2025 | -0.1050 (271) | -0.0796 (163) | -0.1623 (200) | -0.1965 (28) | 0.1708 (254) | -0.1193 (176) | -0.2080 (202) | -0.0179 (28) |
| baseline-b-usdjpy-2026q1 | 0.1111 (63) | -0.1847 (46) | 0.3069 (44) | -0.5000 (5) | 0.1319 (53) | 0.0558 (45) | -0.1520 (56) | 0.2496 (4) |
| baseline-b-usdjpy-2024q1 | 0.3002 (50) | -0.0620 (40) | -0.0996 (50) | -1.0000 (9) | -0.2280 (68) | -0.1072 (42) | 0.0416 (48) | 0.3605 (11) |
| baseline-b-usdjpy-2024q2 | 0.0550 (64) | 0.2203 (41) | 0.4630 (41) | -0.2851 (7) | -0.2935 (46) | -0.2049 (44) | 0.1837 (38) | 0.2500 (4) |
| baseline-b-usdjpy-2024q3 | -0.0085 (58) | -0.1846 (46) | -0.0625 (56) | -0.0619 (8) | -0.0567 (53) | 0.0714 (42) | 0.1572 (54) | 1.4986 (2) |
| baseline-b-usdjpy-2024q4 | 0.0376 (53) | -0.0625 (32) | -0.1305 (46) | -0.3741 (4) | -0.2933 (46) | -0.0624 (40) | -0.0306 (49) | -1.0000 (1) |
| baseline-b-usdjpy-2025q1 | -0.0541 (74) | -0.0971 (36) | -0.2775 (45) | 0.2492 (6) | 0.0353 (70) | -0.0000 (45) | -0.1406 (64) | 0.2500 (4) |
| baseline-b-usdjpy-2025q2 | -0.2338 (62) | -0.1278 (43) | 0.0795 (44) | -0.0620 (8) | 0.3009 (73) | -0.2188 (48) | -0.2686 (41) | -0.4444 (9) |
| baseline-b-usdjpy-2025q3 | -0.1069 (70) | -0.0713 (35) | -0.0623 (48) | -0.3754 (8) | 0.1813 (55) | -0.2860 (42) | -0.0869 (52) | -0.0616 (8) |
| baseline-b-usdjpy-2025q4 | -0.0474 (63) | 0.0231 (44) | -0.2915 (60) | -0.5829 (6) | 0.1360 (55) | -0.0537 (37) | -0.4509 (41) | 0.4276 (7) |
| baseline-b-usdjpy-2026q1-quarter | 0.1111 (63) | -0.1847 (46) | 0.3069 (44) | -0.5000 (5) | 0.1319 (53) | 0.0558 (45) | -0.1520 (56) | 0.2496 (4) |
| baseline-b-eurusd-full-2024-2026q1 | -0.3668 (533) | -0.1589 (425) | -0.1117 (439) | -0.5349 (43) | -0.1192 (423) | -0.0923 (405) | -0.0570 (403) | -0.1100 (45) |
| baseline-b-xauusd-full-2024-2026q1 | -0.0061 (571) | 0.0552 (372) | 0.0576 (513) | 0.1972 (71) | -0.0582 (499) | -0.0297 (456) | -0.1285 (545) | -0.2624 (61) |

## Reject Counts
| Run | RejectedTotal | max_positions_blocked | consecutive_loss_blocked | daily_loss_blocked | spread_too_wide | fibo_filter_failed | rr_too_low | atr_filter_failed | trading_session_blocked | n_wave_filter_failed | invalid_lot_or_risk | stops_invalid |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | 4770 | 2620 | 1320 | 316 | 329 | 184 | 1 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2024 | 2153 | 1333 | 496 | 115 | 117 | 92 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2025 | 2132 | 1008 | 701 | 164 | 175 | 83 | 1 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2026q1 | 479 | 274 | 123 | 37 | 36 | 9 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2024q1 | 516 | 286 | 139 | 35 | 22 | 34 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2024q2 | 586 | 372 | 112 | 26 | 35 | 41 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2024q3 | 488 | 289 | 125 | 33 | 24 | 17 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2024q4 | 547 | 370 | 116 | 25 | 36 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2025q1 | 521 | 234 | 216 | 36 | 35 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2025q2 | 525 | 192 | 167 | 42 | 52 | 72 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2025q3 | 537 | 213 | 215 | 54 | 44 | 11 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2025q4 | 520 | 348 | 96 | 32 | 43 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-usdjpy-2026q1-quarter | 479 | 274 | 123 | 37 | 36 | 9 | 0 | 0 | 0 | 0 | 0 | 0 |
| baseline-b-eurusd-full-2024-2026q1 | 4982 | 2644 | 1475 | 456 | 165 | 238 | 0 | 0 | 0 | 4 | 0 | 0 |
| baseline-b-xauusd-full-2024-2026q1 | 4399 | 2245 | 1409 | 438 | 1 | 284 | 0 | 0 | 0 | 8 | 13 | 1 |

## MaxManagedPositions=2 Risk Diagnostics
- `Concurrent1/2` is classified by open position count at the entry bar, reconstructed from closed virtual trade intervals.
- `NearDuplicateSetupEntries` means same direction, same entry bar, and same rounded neckline price; exact duplicate setup IDs are counted separately and combined in `DuplicateOrNearSetupEntries`.
| Run | MaxHold | C1 Trades | C1 ExpR | C1 PF | C2 Trades | C2 ExpR | C2 PF | C2 MaxDD_R | SameDir2 Entries | OppDir Entries | ExactDup | NearDup | DupOrNear |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | 2 | 1298 | -0.0216 | 0.9645 | 1550 | -0.0500 | 0.9194 | 97.4812 | 839 | 711 | 63 | 0 | 63 |
| baseline-b-usdjpy-2024 | 2 | 522 | 0.0009 | 1.0015 | 677 | -0.0362 | 0.9412 | 47.4916 | 365 | 312 | 27 | 0 | 27 |
| baseline-b-usdjpy-2025 | 2 | 618 | -0.0656 | 0.8952 | 704 | -0.0838 | 0.8677 | 67.0035 | 378 | 326 | 29 | 0 | 29 |
| baseline-b-usdjpy-2026q1 | 2 | 152 | 0.0526 | 1.0909 | 164 | 0.0213 | 1.0361 | 10.9855 | 92 | 72 | 7 | 0 | 7 |
| baseline-b-usdjpy-2024q1 | 2 | 134 | -0.0298 | 0.9514 | 184 | -0.0626 | 0.8999 | 22.5077 | 97 | 87 | 6 | 0 | 6 |
| baseline-b-usdjpy-2024q2 | 2 | 116 | 0.2068 | 1.3998 | 169 | -0.0531 | 0.9145 | 21.4980 | 99 | 70 | 5 | 0 | 5 |
| baseline-b-usdjpy-2024q3 | 2 | 142 | 0.0563 | 1.0975 | 177 | -0.0537 | 0.9136 | 18.4984 | 95 | 82 | 12 | 0 | 12 |
| baseline-b-usdjpy-2024q4 | 2 | 130 | -0.2309 | 0.6665 | 141 | 0.0285 | 1.0484 | 19.9922 | 71 | 70 | 4 | 0 | 4 |
| baseline-b-usdjpy-2025q1 | 2 | 151 | -0.0730 | 0.8839 | 193 | -0.0673 | 0.8926 | 20.5090 | 101 | 92 | 9 | 0 | 9 |
| baseline-b-usdjpy-2025q2 | 2 | 160 | -0.0313 | 0.9489 | 168 | -0.0924 | 0.8549 | 23.0241 | 96 | 72 | 5 | 0 | 5 |
| baseline-b-usdjpy-2025q3 | 2 | 167 | -0.0570 | 0.9085 | 151 | -0.0894 | 0.8593 | 31.5237 | 81 | 70 | 5 | 0 | 5 |
| baseline-b-usdjpy-2025q4 | 2 | 135 | -0.1297 | 0.8011 | 178 | -0.0868 | 0.8632 | 24.9749 | 90 | 88 | 10 | 0 | 10 |
| baseline-b-usdjpy-2026q1-quarter | 2 | 152 | 0.0526 | 1.0909 | 164 | 0.0213 | 1.0361 | 10.9855 | 92 | 72 | 7 | 0 | 7 |
| baseline-b-eurusd-full-2024-2026q1 | 2 | 1261 | -0.2148 | 0.6869 | 1455 | -0.1237 | 0.8096 | 194.4210 | 780 | 675 | 62 | 0 | 62 |
| baseline-b-xauusd-full-2024-2026q1 | 2 | 1445 | -0.0277 | 0.9547 | 1643 | -0.0170 | 0.9719 | 65.0058 | 940 | 703 | 49 | 0 | 49 |

## Artifacts
| Run | Diagnostics | EA Summary | MT5 HTML |
| --- | --- | --- | --- |
| baseline-b-usdjpy-full-2024-2026q1 | [baseline-b-usdjpy-full-2024-2026q1/diagnostics.csv](./baseline-b-usdjpy-full-2024-2026q1/diagnostics.csv) | [baseline-b-usdjpy-full-2024-2026q1/summary.csv](./baseline-b-usdjpy-full-2024-2026q1/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-full-2024-2026q1.htm) |
| baseline-b-usdjpy-2024 | [baseline-b-usdjpy-2024/diagnostics.csv](./baseline-b-usdjpy-2024/diagnostics.csv) | [baseline-b-usdjpy-2024/summary.csv](./baseline-b-usdjpy-2024/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2024.htm) |
| baseline-b-usdjpy-2025 | [baseline-b-usdjpy-2025/diagnostics.csv](./baseline-b-usdjpy-2025/diagnostics.csv) | [baseline-b-usdjpy-2025/summary.csv](./baseline-b-usdjpy-2025/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2025.htm) |
| baseline-b-usdjpy-2026q1 | [baseline-b-usdjpy-2026q1/diagnostics.csv](./baseline-b-usdjpy-2026q1/diagnostics.csv) | [baseline-b-usdjpy-2026q1/summary.csv](./baseline-b-usdjpy-2026q1/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2026q1.htm) |
| baseline-b-usdjpy-2024q1 | [baseline-b-usdjpy-2024q1/diagnostics.csv](./baseline-b-usdjpy-2024q1/diagnostics.csv) | [baseline-b-usdjpy-2024q1/summary.csv](./baseline-b-usdjpy-2024q1/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2024q1.htm) |
| baseline-b-usdjpy-2024q2 | [baseline-b-usdjpy-2024q2/diagnostics.csv](./baseline-b-usdjpy-2024q2/diagnostics.csv) | [baseline-b-usdjpy-2024q2/summary.csv](./baseline-b-usdjpy-2024q2/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2024q2.htm) |
| baseline-b-usdjpy-2024q3 | [baseline-b-usdjpy-2024q3/diagnostics.csv](./baseline-b-usdjpy-2024q3/diagnostics.csv) | [baseline-b-usdjpy-2024q3/summary.csv](./baseline-b-usdjpy-2024q3/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2024q3.htm) |
| baseline-b-usdjpy-2024q4 | [baseline-b-usdjpy-2024q4/diagnostics.csv](./baseline-b-usdjpy-2024q4/diagnostics.csv) | [baseline-b-usdjpy-2024q4/summary.csv](./baseline-b-usdjpy-2024q4/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2024q4.htm) |
| baseline-b-usdjpy-2025q1 | [baseline-b-usdjpy-2025q1/diagnostics.csv](./baseline-b-usdjpy-2025q1/diagnostics.csv) | [baseline-b-usdjpy-2025q1/summary.csv](./baseline-b-usdjpy-2025q1/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2025q1.htm) |
| baseline-b-usdjpy-2025q2 | [baseline-b-usdjpy-2025q2/diagnostics.csv](./baseline-b-usdjpy-2025q2/diagnostics.csv) | [baseline-b-usdjpy-2025q2/summary.csv](./baseline-b-usdjpy-2025q2/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2025q2.htm) |
| baseline-b-usdjpy-2025q3 | [baseline-b-usdjpy-2025q3/diagnostics.csv](./baseline-b-usdjpy-2025q3/diagnostics.csv) | [baseline-b-usdjpy-2025q3/summary.csv](./baseline-b-usdjpy-2025q3/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2025q3.htm) |
| baseline-b-usdjpy-2025q4 | [baseline-b-usdjpy-2025q4/diagnostics.csv](./baseline-b-usdjpy-2025q4/diagnostics.csv) | [baseline-b-usdjpy-2025q4/summary.csv](./baseline-b-usdjpy-2025q4/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2025q4.htm) |
| baseline-b-usdjpy-2026q1-quarter | [baseline-b-usdjpy-2026q1-quarter/diagnostics.csv](./baseline-b-usdjpy-2026q1-quarter/diagnostics.csv) | [baseline-b-usdjpy-2026q1-quarter/summary.csv](./baseline-b-usdjpy-2026q1-quarter/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-usdjpy-2026q1-quarter.htm) |
| baseline-b-eurusd-full-2024-2026q1 | [baseline-b-eurusd-full-2024-2026q1/diagnostics.csv](./baseline-b-eurusd-full-2024-2026q1/diagnostics.csv) | [baseline-b-eurusd-full-2024-2026q1/summary.csv](./baseline-b-eurusd-full-2024-2026q1/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-eurusd-full-2024-2026q1.htm) |
| baseline-b-xauusd-full-2024-2026q1 | [baseline-b-xauusd-full-2024-2026q1/diagnostics.csv](./baseline-b-xauusd-full-2024-2026q1/diagnostics.csv) | [baseline-b-xauusd-full-2024-2026q1/summary.csv](./baseline-b-xauusd-full-2024-2026q1/summary.csv) | [HTML](../../imported/ExpectedValue_NWave_Scalper-baseline-b-xauusd-full-2024-2026q1.htm) |

## Readout
- USDJPY expanded 2024-2026Q1 expectancy: -0.0371R over 2848 closed virtual trades. This is weaker than the 2025.12.31-2026.03.30 Baseline-B candidate and does not yet prove stable positive expectancy.
- Cross-symbol full-window expectancy: EURUSD -0.1660R, XAUUSD -0.0220R. Both are negative in this first pass.
- No strategy logic, session filter, direction filter, partial exit, break-even, trailing, or parameter optimization was added in this cycle.
