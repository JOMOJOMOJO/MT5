# Exit Simulation Diagnostics - USDJPY Full Window

- Generated: 2026-05-14
- EA: `ExpectedValue_NWave_Scalper` / Strategy: `Strategy_01_NWave_ExpectedValue`
- Test: `USDJPY M5`, `2024.01.01` to `2026.03.30`, `EnableTrading=false`, `H4/M15/M5`, `TP=1.5R`, `MinRR=1.2`, `FILTER_ALL`.
- Entry logic is unchanged. The normal virtual fixed-1.5R track remains the entry source; exit modes are parallel diagnostic simulations over the same accepted entries.
- Conservative same-bar handling: if target and stop are both possible in one bar, stop is selected first. For BE modes, if the BE stop and target are both possible in one bar after BE is armed, break-even is selected first. If BE trigger and original SL are both possible in the same bar before BE is armed, original SL is selected first.
- The fixed 1.5R baseline is preserved: MaxPos2 `EXIT_FIXED_R_ONLY` matches the EA summary (`-0.0371R`, PF `0.9397`) within rounding.
- Closed counts can differ by exit mode because earlier-exit simulations may close entries that remained open under fixed 1.5R at the test end.
- MT5 HTML was not produced by the second terminal for these exit-sim runs, but diagnostics, exit simulation, and summary CSV files were produced and copied here.

## Best Mode By Max Position Setting
| Run | Best Mode | Trades | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- |
| MaxPos2 | EXIT_FIXED_R_ONLY | 2848 | -0.0371 | 0.9397 | 141.0338 |
| MaxPos1 | EXIT_PARTIAL_50_AT_05R_REST_15R | 1739 | -0.0641 | 0.8532 | 123.0286 |

## MaxPos2 Exit Mode Summary
| Mode | Closed | Win% | BE% | AvgWinR | AvgLossR | ExpectancyR | PF | MaxLosses | MaxDD_R | LongExpR | ShortExpR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EXIT_FIXED_R_ONLY | 2848 | 38.52 | 0.00 | 1.5000 | -1.0000 | -0.0371 | 0.9397 | 12 | 141.0338 | -0.0378 | -0.0363 |
| EXIT_BE_AT_05R | 2849 | 15.37 | 47.81 | 1.5000 | -1.0000 | -0.1376 | 0.6263 | 6 | 400.4968 | -0.1282 | -0.1471 |
| EXIT_BE_AT_08R | 2848 | 25.60 | 26.97 | 1.5000 | -1.0000 | -0.0904 | 0.8094 | 9 | 275.4955 | -0.0931 | -0.0877 |
| EXIT_BE_AT_10R | 2848 | 29.95 | 17.35 | 1.5000 | -1.0000 | -0.0778 | 0.8524 | 10 | 244.5283 | -0.0722 | -0.0834 |
| EXIT_PARTIAL_50_AT_05R_REST_15R | 2848 | 38.52 | 0.00 | 1.0000 | -0.6993 | -0.0448 | 0.8959 | 12 | 142.7712 | -0.0570 | -0.0323 |
| EXIT_PARTIAL_50_AT_10R_REST_15R | 2848 | 38.52 | 8.78 | 1.2500 | -1.0000 | -0.0456 | 0.9135 | 11 | 147.5186 | -0.0547 | -0.0362 |
| EXIT_TP_12R_FIXED | 2848 | 43.33 | 0.00 | 1.2000 | -1.0000 | -0.0468 | 0.9175 | 10 | 153.0000 | -0.0615 | -0.0318 |
| EXIT_TP_15R_FIXED | 2848 | 38.52 | 0.00 | 1.5000 | -1.0000 | -0.0371 | 0.9397 | 12 | 141.0338 | -0.0378 | -0.0363 |

## MaxPos1 Exit Mode Summary
| Mode | Closed | Win% | BE% | AvgWinR | AvgLossR | ExpectancyR | PF | MaxLosses | MaxDD_R | LongExpR | ShortExpR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EXIT_FIXED_R_ONLY | 1739 | 37.26 | 0.00 | 1.4999 | -1.0000 | -0.0685 | 0.8909 | 12 | 141.5543 | -0.0717 | -0.0652 |
| EXIT_BE_AT_05R | 1740 | 15.34 | 47.36 | 1.4998 | -1.0000 | -0.1428 | 0.6170 | 7 | 257.0305 | -0.1303 | -0.1554 |
| EXIT_BE_AT_08R | 1739 | 25.30 | 26.68 | 1.4999 | -1.0000 | -0.1007 | 0.7904 | 9 | 192.5329 | -0.0913 | -0.1100 |
| EXIT_BE_AT_10R | 1739 | 29.21 | 17.42 | 1.4999 | -1.0000 | -0.0955 | 0.8211 | 9 | 188.0492 | -0.0827 | -0.1083 |
| EXIT_PARTIAL_50_AT_05R_REST_15R | 1739 | 37.26 | 0.00 | 1.0000 | -0.6962 | -0.0641 | 0.8532 | 12 | 123.0286 | -0.0764 | -0.0519 |
| EXIT_PARTIAL_50_AT_10R_REST_15R | 1739 | 37.26 | 9.37 | 1.2500 | -1.0000 | -0.0679 | 0.8728 | 9 | 135.0271 | -0.0773 | -0.0585 |
| EXIT_TP_12R_FIXED | 1739 | 42.44 | 0.00 | 1.2000 | -1.0000 | -0.0664 | 0.8847 | 11 | 131.2000 | -0.0795 | -0.0532 |
| EXIT_TP_15R_FIXED | 1739 | 37.26 | 0.00 | 1.4999 | -1.0000 | -0.0685 | 0.8909 | 12 | 141.5543 | -0.0717 | -0.0652 |

## User Hypothesis Focus
| Run | Candidate | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MaxPos2 | G_entry_open_0_countertrend | EXIT_BE_AT_10R | 466 | 33.69 | 0.0030 | 1.0061 | 32.0438 |
| MaxPos2 | G_entry_open_0_countertrend | EXIT_FIXED_R_ONLY | 466 | 41.85 | 0.0460 | 1.0791 | 24.0210 |
| MaxPos2 | G_entry_open_0_countertrend | EXIT_TP_15R_FIXED | 466 | 41.85 | 0.0460 | 1.0791 | 24.0210 |
| MaxPos2 | H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 172 | 37.79 | 0.0724 | 1.1465 | 11.0057 |
| MaxPos2 | H_entry_open_0_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 172 | 45.93 | 0.1480 | 1.2738 | 11.0053 |
| MaxPos2 | H_entry_open_0_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 172 | 45.93 | 0.1480 | 1.2738 | 11.0053 |
| MaxPos2 | J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_10R | 128 | 39.84 | 0.1052 | 1.2137 | 12.0034 |
| MaxPos2 | J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_FIXED_R_ONLY | 128 | 46.88 | 0.1716 | 1.3231 | 12.4998 |
| MaxPos2 | J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_15R_FIXED | 128 | 46.88 | 0.1716 | 1.3231 | 12.4998 |
| MaxPos1 | G_entry_open_0_countertrend | EXIT_BE_AT_10R | 620 | 31.13 | -0.0348 | 0.9307 | 53.0254 |
| MaxPos1 | G_entry_open_0_countertrend | EXIT_FIXED_R_ONLY | 620 | 40.00 | -0.0001 | 0.9999 | 50.5315 |
| MaxPos1 | G_entry_open_0_countertrend | EXIT_TP_15R_FIXED | 620 | 40.00 | -0.0001 | 0.9999 | 50.5315 |
| MaxPos1 | H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 236 | 33.90 | -0.0043 | 0.9915 | 15.0153 |
| MaxPos1 | H_entry_open_0_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 236 | 41.53 | 0.0381 | 1.0652 | 19.0177 |
| MaxPos1 | H_entry_open_0_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 236 | 41.53 | 0.0381 | 1.0652 | 19.0177 |
| MaxPos1 | J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_10R | 172 | 36.05 | 0.0347 | 1.0686 | 10.5204 |
| MaxPos1 | J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_FIXED_R_ONLY | 172 | 41.86 | 0.0464 | 1.0797 | 14.0132 |
| MaxPos1 | J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_15R_FIXED | 172 | 41.86 | 0.0464 | 1.0797 | 14.0132 |

## MaxPos2 Candidate Filters x Exit Mode
| Candidate | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| A_all_trades | EXIT_FIXED_R_ONLY | 2848 | 38.52 | -0.0371 | 0.9397 | 141.0338 |
| A_all_trades | EXIT_BE_AT_05R | 2849 | 15.37 | -0.1376 | 0.6263 | 400.4968 |
| A_all_trades | EXIT_BE_AT_08R | 2848 | 25.60 | -0.0904 | 0.8094 | 275.4955 |
| A_all_trades | EXIT_BE_AT_10R | 2848 | 29.95 | -0.0778 | 0.8524 | 244.5283 |
| A_all_trades | EXIT_PARTIAL_50_AT_05R_REST_15R | 2848 | 38.52 | -0.0448 | 0.8959 | 142.7712 |
| A_all_trades | EXIT_PARTIAL_50_AT_10R_REST_15R | 2848 | 38.52 | -0.0456 | 0.9135 | 147.5186 |
| A_all_trades | EXIT_TP_12R_FIXED | 2848 | 43.33 | -0.0468 | 0.9175 | 153.0000 |
| A_all_trades | EXIT_TP_15R_FIXED | 2848 | 38.52 | -0.0371 | 0.9397 | 141.0338 |
| B_countertrend_only | EXIT_FIXED_R_ONLY | 1000 | 40.40 | 0.0099 | 1.0166 | 48.0093 |
| B_countertrend_only | EXIT_BE_AT_05R | 1000 | 16.80 | -0.1000 | 0.7158 | 109.5138 |
| B_countertrend_only | EXIT_BE_AT_08R | 1000 | 26.80 | -0.0461 | 0.8971 | 67.5139 |
| B_countertrend_only | EXIT_BE_AT_10R | 1000 | 31.80 | -0.0171 | 0.9654 | 55.0188 |
| B_countertrend_only | EXIT_PARTIAL_50_AT_05R_REST_15R | 1000 | 40.40 | -0.0090 | 0.9781 | 40.7744 |
| B_countertrend_only | EXIT_PARTIAL_50_AT_10R_REST_15R | 1000 | 40.40 | 0.0110 | 1.0222 | 34.5244 |
| B_countertrend_only | EXIT_TP_12R_FIXED | 1000 | 45.90 | 0.0098 | 1.0181 | 31.8000 |
| B_countertrend_only | EXIT_TP_15R_FIXED | 1000 | 40.40 | 0.0099 | 1.0166 | 48.0093 |
| C_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 402 | 45.02 | 0.1255 | 1.2283 | 16.9978 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_05R | 402 | 20.40 | -0.0100 | 0.9684 | 17.4896 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_08R | 402 | 31.84 | 0.0696 | 1.1705 | 13.0000 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 402 | 35.82 | 0.0770 | 1.1674 | 12.4997 |
| C_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_05R_REST_15R | 402 | 45.02 | 0.0758 | 1.2025 | 10.0032 |
| C_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 402 | 45.02 | 0.1026 | 1.2229 | 12.2499 |
| C_countertrend_pattern_adx_middle | EXIT_TP_12R_FIXED | 402 | 48.51 | 0.0672 | 1.1304 | 13.2000 |
| C_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 402 | 45.02 | 0.1255 | 1.2283 | 16.9978 |
| D_countertrend_break_high | EXIT_FIXED_R_ONLY | 760 | 41.32 | 0.0328 | 1.0558 | 45.4940 |
| D_countertrend_break_high | EXIT_BE_AT_05R | 760 | 16.97 | -0.0783 | 0.7648 | 68.0009 |
| D_countertrend_break_high | EXIT_BE_AT_08R | 760 | 28.03 | -0.0086 | 0.9799 | 38.0077 |
| D_countertrend_break_high | EXIT_BE_AT_10R | 760 | 33.03 | 0.0124 | 1.0257 | 41.5153 |
| D_countertrend_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 760 | 41.32 | 0.0167 | 1.0421 | 25.2485 |
| D_countertrend_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 760 | 41.32 | 0.0335 | 1.0693 | 29.2470 |
| D_countertrend_break_high | EXIT_TP_12R_FIXED | 760 | 46.84 | 0.0305 | 1.0574 | 23.6000 |
| D_countertrend_break_high | EXIT_TP_15R_FIXED | 760 | 41.32 | 0.0328 | 1.0558 | 45.4940 |
| E_pattern_adx_middle_break_high | EXIT_FIXED_R_ONLY | 909 | 42.57 | 0.0643 | 1.1119 | 26.5149 |
| E_pattern_adx_middle_break_high | EXIT_BE_AT_05R | 909 | 16.50 | -0.0880 | 0.7376 | 88.5177 |
| E_pattern_adx_middle_break_high | EXIT_BE_AT_08R | 909 | 28.71 | -0.0127 | 0.9714 | 40.9768 |
| E_pattern_adx_middle_break_high | EXIT_BE_AT_10R | 909 | 33.22 | 0.0043 | 1.0088 | 37.9931 |
| E_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 909 | 42.57 | 0.0305 | 1.0772 | 20.7538 |
| E_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 909 | 42.57 | 0.0382 | 1.0773 | 31.2538 |
| E_pattern_adx_middle_break_high | EXIT_TP_12R_FIXED | 909 | 46.53 | 0.0238 | 1.0444 | 36.0000 |
| E_pattern_adx_middle_break_high | EXIT_TP_15R_FIXED | 909 | 42.57 | 0.0643 | 1.1119 | 26.5149 |
| F_entry_open_0_only | EXIT_FIXED_R_ONLY | 1298 | 39.14 | -0.0216 | 0.9645 | 81.0497 |
| F_entry_open_0_only | EXIT_BE_AT_05R | 1299 | 16.40 | -0.1282 | 0.6574 | 172.0206 |
| F_entry_open_0_only | EXIT_BE_AT_08R | 1298 | 26.66 | -0.0825 | 0.8290 | 116.5433 |
| F_entry_open_0_only | EXIT_BE_AT_10R | 1298 | 30.97 | -0.0663 | 0.8751 | 100.5646 |
| F_entry_open_0_only | EXIT_PARTIAL_50_AT_05R_REST_15R | 1298 | 39.14 | -0.0416 | 0.9039 | 81.5249 |
| F_entry_open_0_only | EXIT_PARTIAL_50_AT_10R_REST_15R | 1298 | 39.14 | -0.0416 | 0.9216 | 84.0249 |
| F_entry_open_0_only | EXIT_TP_12R_FIXED | 1298 | 43.30 | -0.0475 | 0.9163 | 84.0000 |
| F_entry_open_0_only | EXIT_TP_15R_FIXED | 1298 | 39.14 | -0.0216 | 0.9645 | 81.0497 |
| G_entry_open_0_countertrend | EXIT_FIXED_R_ONLY | 466 | 41.85 | 0.0460 | 1.0791 | 24.0210 |
| G_entry_open_0_countertrend | EXIT_BE_AT_05R | 466 | 18.88 | -0.0945 | 0.7498 | 49.0421 |
| G_entry_open_0_countertrend | EXIT_BE_AT_08R | 466 | 29.40 | -0.0248 | 0.9467 | 37.5342 |
| G_entry_open_0_countertrend | EXIT_BE_AT_10R | 466 | 33.69 | 0.0030 | 1.0061 | 32.0438 |
| G_entry_open_0_countertrend | EXIT_PARTIAL_50_AT_05R_REST_15R | 466 | 41.85 | -0.0103 | 0.9760 | 24.7727 |
| G_entry_open_0_countertrend | EXIT_PARTIAL_50_AT_10R_REST_15R | 466 | 41.85 | 0.0208 | 1.0415 | 26.0105 |
| G_entry_open_0_countertrend | EXIT_TP_12R_FIXED | 466 | 46.35 | 0.0197 | 1.0368 | 22.2000 |
| G_entry_open_0_countertrend | EXIT_TP_15R_FIXED | 466 | 41.85 | 0.0460 | 1.0791 | 24.0210 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 172 | 45.93 | 0.1480 | 1.2738 | 11.0053 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_05R | 172 | 22.67 | -0.0321 | 0.9137 | 12.0083 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_08R | 172 | 33.72 | 0.0462 | 1.1007 | 12.5057 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 172 | 37.79 | 0.0724 | 1.1465 | 11.0057 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_05R_REST_15R | 172 | 45.93 | 0.0449 | 1.1085 | 9.5049 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 172 | 45.93 | 0.0798 | 1.1615 | 10.5027 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_TP_12R_FIXED | 172 | 48.26 | 0.0616 | 1.1191 | 8.6000 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 172 | 45.93 | 0.1480 | 1.2738 | 11.0053 |
| I_entry_open_0_countertrend_break_high | EXIT_FIXED_R_ONLY | 351 | 43.30 | 0.0825 | 1.1455 | 28.5073 |
| I_entry_open_0_countertrend_break_high | EXIT_BE_AT_05R | 351 | 18.52 | -0.0727 | 0.7926 | 38.5110 |
| I_entry_open_0_countertrend_break_high | EXIT_BE_AT_08R | 351 | 30.77 | 0.0170 | 1.0381 | 29.5222 |
| I_entry_open_0_countertrend_break_high | EXIT_BE_AT_10R | 351 | 35.33 | 0.0426 | 1.0874 | 29.0268 |
| I_entry_open_0_countertrend_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 351 | 43.30 | 0.0284 | 1.0703 | 17.9993 |
| I_entry_open_0_countertrend_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 351 | 43.30 | 0.0541 | 1.1110 | 24.7536 |
| I_entry_open_0_countertrend_break_high | EXIT_TP_12R_FIXED | 351 | 47.86 | 0.0530 | 1.1016 | 18.6000 |
| I_entry_open_0_countertrend_break_high | EXIT_TP_15R_FIXED | 351 | 43.30 | 0.0825 | 1.1455 | 28.5073 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_FIXED_R_ONLY | 128 | 46.88 | 0.1716 | 1.3231 | 12.4998 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_05R | 128 | 22.66 | -0.0118 | 0.9664 | 13.5077 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_08R | 128 | 35.94 | 0.0778 | 1.1689 | 13.5134 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_10R | 128 | 39.84 | 0.1052 | 1.2137 | 12.0034 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 128 | 46.88 | 0.0721 | 1.1819 | 9.2499 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 128 | 46.88 | 0.0936 | 1.1902 | 12.2544 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_12R_FIXED | 128 | 48.44 | 0.0656 | 1.1273 | 10.8000 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_15R_FIXED | 128 | 46.88 | 0.1716 | 1.3231 | 12.4998 |

## MaxPos1 Candidate Filters x Exit Mode
| Candidate | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| A_all_trades | EXIT_FIXED_R_ONLY | 1739 | 37.26 | -0.0685 | 0.8909 | 141.5543 |
| A_all_trades | EXIT_BE_AT_05R | 1740 | 15.34 | -0.1428 | 0.6170 | 257.0305 |
| A_all_trades | EXIT_BE_AT_08R | 1739 | 25.30 | -0.1007 | 0.7904 | 192.5329 |
| A_all_trades | EXIT_BE_AT_10R | 1739 | 29.21 | -0.0955 | 0.8211 | 188.0492 |
| A_all_trades | EXIT_PARTIAL_50_AT_05R_REST_15R | 1739 | 37.26 | -0.0641 | 0.8532 | 123.0286 |
| A_all_trades | EXIT_PARTIAL_50_AT_10R_REST_15R | 1739 | 37.26 | -0.0679 | 0.8728 | 135.0271 |
| A_all_trades | EXIT_TP_12R_FIXED | 1739 | 42.44 | -0.0664 | 0.8847 | 131.2000 |
| A_all_trades | EXIT_TP_15R_FIXED | 1739 | 37.26 | -0.0685 | 0.8909 | 141.5543 |
| B_countertrend_only | EXIT_FIXED_R_ONLY | 620 | 40.00 | -0.0001 | 0.9999 | 50.5315 |
| B_countertrend_only | EXIT_BE_AT_05R | 620 | 16.13 | -0.1242 | 0.6607 | 87.5292 |
| B_countertrend_only | EXIT_BE_AT_08R | 620 | 26.77 | -0.0581 | 0.8735 | 63.0227 |
| B_countertrend_only | EXIT_BE_AT_10R | 620 | 31.13 | -0.0348 | 0.9307 | 53.0254 |
| B_countertrend_only | EXIT_PARTIAL_50_AT_05R_REST_15R | 620 | 40.00 | -0.0246 | 0.9420 | 45.0158 |
| B_countertrend_only | EXIT_PARTIAL_50_AT_10R_REST_15R | 620 | 40.00 | -0.0017 | 0.9967 | 42.7658 |
| B_countertrend_only | EXIT_TP_12R_FIXED | 620 | 45.48 | 0.0006 | 1.0012 | 37.6000 |
| B_countertrend_only | EXIT_TP_15R_FIXED | 620 | 40.00 | -0.0001 | 0.9999 | 50.5315 |
| C_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 236 | 41.53 | 0.0381 | 1.0652 | 19.0177 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_05R | 236 | 19.07 | -0.0742 | 0.7939 | 26.5099 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_08R | 236 | 29.66 | -0.0128 | 0.9720 | 21.0177 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 236 | 33.90 | -0.0043 | 0.9915 | 15.0153 |
| C_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_05R_REST_15R | 236 | 41.53 | -0.0011 | 0.9974 | 17.5087 |
| C_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 236 | 41.53 | 0.0063 | 1.0124 | 19.5060 |
| C_countertrend_pattern_adx_middle | EXIT_TP_12R_FIXED | 236 | 44.92 | -0.0119 | 0.9785 | 20.4000 |
| C_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 236 | 41.53 | 0.0381 | 1.0652 | 19.0177 |
| D_countertrend_break_high | EXIT_FIXED_R_ONLY | 452 | 41.37 | 0.0342 | 1.0583 | 30.5217 |
| D_countertrend_break_high | EXIT_BE_AT_05R | 452 | 16.81 | -0.0929 | 0.7308 | 54.4999 |
| D_countertrend_break_high | EXIT_BE_AT_08R | 452 | 27.88 | -0.0178 | 0.9592 | 40.5120 |
| D_countertrend_break_high | EXIT_BE_AT_10R | 452 | 32.52 | 0.0032 | 1.0067 | 33.5160 |
| D_countertrend_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 452 | 41.37 | 0.0082 | 1.0203 | 22.5091 |
| D_countertrend_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 452 | 41.37 | 0.0326 | 1.0672 | 25.4970 |
| D_countertrend_break_high | EXIT_TP_12R_FIXED | 452 | 47.12 | 0.0367 | 1.0695 | 18.0000 |
| D_countertrend_break_high | EXIT_TP_15R_FIXED | 452 | 41.37 | 0.0342 | 1.0583 | 30.5217 |
| E_pattern_adx_middle_break_high | EXIT_FIXED_R_ONLY | 533 | 41.09 | 0.0272 | 1.0461 | 30.5161 |
| E_pattern_adx_middle_break_high | EXIT_BE_AT_05R | 533 | 17.45 | -0.0929 | 0.7380 | 60.0114 |
| E_pattern_adx_middle_break_high | EXIT_BE_AT_08R | 533 | 28.71 | -0.0253 | 0.9444 | 42.5040 |
| E_pattern_adx_middle_break_high | EXIT_BE_AT_10R | 533 | 32.83 | -0.0160 | 0.9686 | 29.5141 |
| E_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 533 | 41.09 | -0.0024 | 0.9943 | 25.2580 |
| E_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 533 | 41.09 | 0.0051 | 1.0101 | 30.0106 |
| E_pattern_adx_middle_break_high | EXIT_TP_12R_FIXED | 533 | 45.03 | -0.0094 | 0.9829 | 30.6000 |
| E_pattern_adx_middle_break_high | EXIT_TP_15R_FIXED | 533 | 41.09 | 0.0272 | 1.0461 | 30.5161 |
| F_entry_open_0_only | EXIT_FIXED_R_ONLY | 1739 | 37.26 | -0.0685 | 0.8909 | 141.5543 |
| F_entry_open_0_only | EXIT_BE_AT_05R | 1740 | 15.34 | -0.1428 | 0.6170 | 257.0305 |
| F_entry_open_0_only | EXIT_BE_AT_08R | 1739 | 25.30 | -0.1007 | 0.7904 | 192.5329 |
| F_entry_open_0_only | EXIT_BE_AT_10R | 1739 | 29.21 | -0.0955 | 0.8211 | 188.0492 |
| F_entry_open_0_only | EXIT_PARTIAL_50_AT_05R_REST_15R | 1739 | 37.26 | -0.0641 | 0.8532 | 123.0286 |
| F_entry_open_0_only | EXIT_PARTIAL_50_AT_10R_REST_15R | 1739 | 37.26 | -0.0679 | 0.8728 | 135.0271 |
| F_entry_open_0_only | EXIT_TP_12R_FIXED | 1739 | 42.44 | -0.0664 | 0.8847 | 131.2000 |
| F_entry_open_0_only | EXIT_TP_15R_FIXED | 1739 | 37.26 | -0.0685 | 0.8909 | 141.5543 |
| G_entry_open_0_countertrend | EXIT_FIXED_R_ONLY | 620 | 40.00 | -0.0001 | 0.9999 | 50.5315 |
| G_entry_open_0_countertrend | EXIT_BE_AT_05R | 620 | 16.13 | -0.1242 | 0.6607 | 87.5292 |
| G_entry_open_0_countertrend | EXIT_BE_AT_08R | 620 | 26.77 | -0.0581 | 0.8735 | 63.0227 |
| G_entry_open_0_countertrend | EXIT_BE_AT_10R | 620 | 31.13 | -0.0348 | 0.9307 | 53.0254 |
| G_entry_open_0_countertrend | EXIT_PARTIAL_50_AT_05R_REST_15R | 620 | 40.00 | -0.0246 | 0.9420 | 45.0158 |
| G_entry_open_0_countertrend | EXIT_PARTIAL_50_AT_10R_REST_15R | 620 | 40.00 | -0.0017 | 0.9967 | 42.7658 |
| G_entry_open_0_countertrend | EXIT_TP_12R_FIXED | 620 | 45.48 | 0.0006 | 1.0012 | 37.6000 |
| G_entry_open_0_countertrend | EXIT_TP_15R_FIXED | 620 | 40.00 | -0.0001 | 0.9999 | 50.5315 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 236 | 41.53 | 0.0381 | 1.0652 | 19.0177 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_05R | 236 | 19.07 | -0.0742 | 0.7939 | 26.5099 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_08R | 236 | 29.66 | -0.0128 | 0.9720 | 21.0177 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 236 | 33.90 | -0.0043 | 0.9915 | 15.0153 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_05R_REST_15R | 236 | 41.53 | -0.0011 | 0.9974 | 17.5087 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 236 | 41.53 | 0.0063 | 1.0124 | 19.5060 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_TP_12R_FIXED | 236 | 44.92 | -0.0119 | 0.9785 | 20.4000 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 236 | 41.53 | 0.0381 | 1.0652 | 19.0177 |
| I_entry_open_0_countertrend_break_high | EXIT_FIXED_R_ONLY | 452 | 41.37 | 0.0342 | 1.0583 | 30.5217 |
| I_entry_open_0_countertrend_break_high | EXIT_BE_AT_05R | 452 | 16.81 | -0.0929 | 0.7308 | 54.4999 |
| I_entry_open_0_countertrend_break_high | EXIT_BE_AT_08R | 452 | 27.88 | -0.0178 | 0.9592 | 40.5120 |
| I_entry_open_0_countertrend_break_high | EXIT_BE_AT_10R | 452 | 32.52 | 0.0032 | 1.0067 | 33.5160 |
| I_entry_open_0_countertrend_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 452 | 41.37 | 0.0082 | 1.0203 | 22.5091 |
| I_entry_open_0_countertrend_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 452 | 41.37 | 0.0326 | 1.0672 | 25.4970 |
| I_entry_open_0_countertrend_break_high | EXIT_TP_12R_FIXED | 452 | 47.12 | 0.0367 | 1.0695 | 18.0000 |
| I_entry_open_0_countertrend_break_high | EXIT_TP_15R_FIXED | 452 | 41.37 | 0.0342 | 1.0583 | 30.5217 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_FIXED_R_ONLY | 172 | 41.86 | 0.0464 | 1.0797 | 14.0132 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_05R | 172 | 19.77 | -0.0524 | 0.8497 | 19.5147 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_08R | 172 | 31.98 | 0.0260 | 1.0573 | 17.0182 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_10R | 172 | 36.05 | 0.0347 | 1.0686 | 10.5204 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 172 | 41.86 | 0.0116 | 1.0284 | 10.2586 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 172 | 41.86 | 0.0174 | 1.0343 | 12.0066 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_12R_FIXED | 172 | 45.35 | -0.0023 | 0.9957 | 11.4000 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_15R_FIXED | 172 | 41.86 | 0.0464 | 1.0797 | 14.0132 |

## MaxPos2 TrendAlignmentTag x Exit Mode
| TrendAlignmentTag | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| CounterTrend | EXIT_FIXED_R_ONLY | 1000 | 40.40 | 0.0099 | 1.0166 | 48.0093 |
| CounterTrend | EXIT_BE_AT_05R | 1000 | 16.80 | -0.1000 | 0.7158 | 109.5138 |
| CounterTrend | EXIT_BE_AT_08R | 1000 | 26.80 | -0.0461 | 0.8971 | 67.5139 |
| CounterTrend | EXIT_BE_AT_10R | 1000 | 31.80 | -0.0171 | 0.9654 | 55.0188 |
| CounterTrend | EXIT_PARTIAL_50_AT_05R_REST_15R | 1000 | 40.40 | -0.0090 | 0.9781 | 40.7744 |
| CounterTrend | EXIT_PARTIAL_50_AT_10R_REST_15R | 1000 | 40.40 | 0.0110 | 1.0222 | 34.5244 |
| CounterTrend | EXIT_TP_12R_FIXED | 1000 | 45.90 | 0.0098 | 1.0181 | 31.8000 |
| CounterTrend | EXIT_TP_15R_FIXED | 1000 | 40.40 | 0.0099 | 1.0166 | 48.0093 |
| MixedTrend | EXIT_FIXED_R_ONLY | 895 | 38.77 | -0.0307 | 0.9498 | 73.0091 |
| MixedTrend | EXIT_BE_AT_05R | 895 | 12.51 | -0.1676 | 0.5283 | 154.9968 |
| MixedTrend | EXIT_BE_AT_08R | 895 | 24.69 | -0.0989 | 0.7893 | 106.5162 |
| MixedTrend | EXIT_BE_AT_10R | 895 | 28.49 | -0.1011 | 0.8086 | 111.0267 |
| MixedTrend | EXIT_PARTIAL_50_AT_05R_REST_15R | 895 | 38.77 | -0.0318 | 0.9241 | 59.5073 |
| MixedTrend | EXIT_PARTIAL_50_AT_10R_REST_15R | 895 | 38.77 | -0.0439 | 0.9170 | 75.5045 |
| MixedTrend | EXIT_TP_12R_FIXED | 895 | 43.35 | -0.0463 | 0.9183 | 80.2000 |
| MixedTrend | EXIT_TP_15R_FIXED | 895 | 38.77 | -0.0307 | 0.9498 | 73.0091 |
| TrendFollow | EXIT_FIXED_R_ONLY | 953 | 36.31 | -0.0923 | 0.8551 | 101.9553 |
| TrendFollow | EXIT_BE_AT_05R | 954 | 16.56 | -0.1488 | 0.6254 | 150.4812 |
| TrendFollow | EXIT_BE_AT_08R | 953 | 25.18 | -0.1290 | 0.7455 | 132.4179 |
| TrendFollow | EXIT_BE_AT_10R | 953 | 29.38 | -0.1196 | 0.7866 | 125.9344 |
| TrendFollow | EXIT_PARTIAL_50_AT_05R_REST_15R | 953 | 36.31 | -0.0944 | 0.7937 | 99.7144 |
| TrendFollow | EXIT_PARTIAL_50_AT_10R_REST_15R | 953 | 36.31 | -0.1065 | 0.8100 | 112.4644 |
| TrendFollow | EXIT_TP_12R_FIXED | 953 | 40.61 | -0.1066 | 0.8205 | 113.0000 |
| TrendFollow | EXIT_TP_15R_FIXED | 953 | 36.31 | -0.0923 | 0.8551 | 101.9553 |

## MaxPos2 PatternADXBucket x Exit Mode
| PatternADXBucket | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| high | EXIT_FIXED_R_ONLY | 1071 | 36.69 | -0.0826 | 0.8695 | 99.5086 |
| high | EXIT_BE_AT_05R | 1071 | 14.66 | -0.1667 | 0.5688 | 181.9994 |
| high | EXIT_BE_AT_08R | 1071 | 23.62 | -0.1424 | 0.7133 | 160.5165 |
| high | EXIT_BE_AT_10R | 1071 | 28.20 | -0.1177 | 0.7824 | 137.0234 |
| high | EXIT_PARTIAL_50_AT_05R_REST_15R | 1071 | 36.69 | -0.0812 | 0.8187 | 93.0043 |
| high | EXIT_PARTIAL_50_AT_10R_REST_15R | 1071 | 36.69 | -0.0819 | 0.8484 | 96.2543 |
| high | EXIT_TP_12R_FIXED | 1071 | 41.92 | -0.0777 | 0.8662 | 91.2000 |
| high | EXIT_TP_15R_FIXED | 1071 | 36.69 | -0.0826 | 0.8695 | 99.5086 |
| low | EXIT_FIXED_R_ONLY | 601 | 36.61 | -0.0849 | 0.8662 | 66.4902 |
| low | EXIT_BE_AT_05R | 602 | 14.45 | -0.1487 | 0.5932 | 96.9824 |
| low | EXIT_BE_AT_08R | 601 | 24.63 | -0.1048 | 0.7790 | 72.4709 |
| low | EXIT_BE_AT_10R | 601 | 28.79 | -0.1073 | 0.8010 | 76.4762 |
| low | EXIT_PARTIAL_50_AT_05R_REST_15R | 601 | 36.61 | -0.0670 | 0.8453 | 50.2457 |
| low | EXIT_PARTIAL_50_AT_10R_REST_15R | 601 | 36.61 | -0.0815 | 0.8488 | 60.7451 |
| low | EXIT_TP_12R_FIXED | 601 | 42.10 | -0.0739 | 0.8724 | 57.8000 |
| low | EXIT_TP_15R_FIXED | 601 | 36.61 | -0.0849 | 0.8662 | 66.4902 |
| middle | EXIT_FIXED_R_ONLY | 1176 | 41.16 | 0.0289 | 1.0491 | 24.0015 |
| middle | EXIT_BE_AT_05R | 1176 | 16.50 | -0.1055 | 0.7012 | 130.5153 |
| middle | EXIT_BE_AT_08R | 1176 | 27.89 | -0.0357 | 0.9213 | 55.0103 |
| middle | EXIT_BE_AT_10R | 1176 | 32.14 | -0.0264 | 0.9481 | 46.0404 |
| middle | EXIT_PARTIAL_50_AT_05R_REST_15R | 1176 | 41.16 | -0.0002 | 0.9994 | 24.7712 |
| middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 1176 | 41.16 | 0.0059 | 1.0117 | 29.5197 |
| middle | EXIT_TP_12R_FIXED | 1176 | 45.24 | -0.0048 | 0.9913 | 45.8000 |
| middle | EXIT_TP_15R_FIXED | 1176 | 41.16 | 0.0289 | 1.0491 | 24.0015 |

## MaxPos2 BreakCandleStrengthBucket x Exit Mode
| BreakCandleStrengthBucket | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| high | EXIT_FIXED_R_ONLY | 2188 | 39.67 | -0.0083 | 0.9863 | 76.5283 |
| high | EXIT_BE_AT_05R | 2189 | 15.53 | -0.1220 | 0.6564 | 273.9783 |
| high | EXIT_BE_AT_08R | 2188 | 26.28 | -0.0670 | 0.8548 | 160.0084 |
| high | EXIT_BE_AT_10R | 2188 | 30.58 | -0.0551 | 0.8928 | 140.5255 |
| high | EXIT_PARTIAL_50_AT_05R_REST_15R | 2188 | 39.67 | -0.0205 | 0.9509 | 77.7563 |
| high | EXIT_PARTIAL_50_AT_10R_REST_15R | 2188 | 39.67 | -0.0178 | 0.9653 | 85.0057 |
| high | EXIT_TP_12R_FIXED | 2188 | 44.61 | -0.0186 | 0.9663 | 84.0000 |
| high | EXIT_TP_15R_FIXED | 2188 | 39.67 | -0.0083 | 0.9863 | 76.5283 |
| low | EXIT_FIXED_R_ONLY | 117 | 35.90 | -0.1027 | 0.8397 | 18.5143 |
| low | EXIT_BE_AT_05R | 117 | 16.24 | -0.1497 | 0.6192 | 20.0221 |
| low | EXIT_BE_AT_08R | 117 | 22.22 | -0.1711 | 0.6606 | 24.0209 |
| low | EXIT_BE_AT_10R | 117 | 28.21 | -0.1327 | 0.7612 | 22.0148 |
| low | EXIT_PARTIAL_50_AT_05R_REST_15R | 117 | 35.90 | -0.0962 | 0.7885 | 16.5072 |
| low | EXIT_PARTIAL_50_AT_10R_REST_15R | 117 | 35.90 | -0.1069 | 0.8075 | 17.2572 |
| low | EXIT_TP_12R_FIXED | 117 | 41.88 | -0.0786 | 0.8647 | 14.8000 |
| low | EXIT_TP_15R_FIXED | 117 | 35.90 | -0.1027 | 0.8397 | 18.5143 |
| middle | EXIT_FIXED_R_ONLY | 543 | 34.44 | -0.1390 | 0.7881 | 90.9545 |
| middle | EXIT_BE_AT_05R | 543 | 14.55 | -0.1980 | 0.5243 | 110.4967 |
| middle | EXIT_BE_AT_08R | 543 | 23.57 | -0.1675 | 0.6785 | 101.9740 |
| middle | EXIT_BE_AT_10R | 543 | 27.81 | -0.1574 | 0.7261 | 99.9758 |
| middle | EXIT_PARTIAL_50_AT_05R_REST_15R | 543 | 34.44 | -0.1316 | 0.7235 | 81.9749 |
| middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 543 | 34.44 | -0.1441 | 0.7493 | 91.4761 |
| middle | EXIT_TP_12R_FIXED | 543 | 38.49 | -0.1532 | 0.7509 | 95.8000 |
| middle | EXIT_TP_15R_FIXED | 543 | 34.44 | -0.1390 | 0.7881 | 90.9545 |

## MaxPos2 EntryOpenCount x Exit Mode
| EntryOpenCount | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | EXIT_FIXED_R_ONLY | 1298 | 39.14 | -0.0216 | 0.9645 | 81.0497 |
| 0 | EXIT_BE_AT_05R | 1299 | 16.40 | -0.1282 | 0.6574 | 172.0206 |
| 0 | EXIT_BE_AT_08R | 1298 | 26.66 | -0.0825 | 0.8290 | 116.5433 |
| 0 | EXIT_BE_AT_10R | 1298 | 30.97 | -0.0663 | 0.8751 | 100.5646 |
| 0 | EXIT_PARTIAL_50_AT_05R_REST_15R | 1298 | 39.14 | -0.0416 | 0.9039 | 81.5249 |
| 0 | EXIT_PARTIAL_50_AT_10R_REST_15R | 1298 | 39.14 | -0.0416 | 0.9216 | 84.0249 |
| 0 | EXIT_TP_12R_FIXED | 1298 | 43.30 | -0.0475 | 0.9163 | 84.0000 |
| 0 | EXIT_TP_15R_FIXED | 1298 | 39.14 | -0.0216 | 0.9645 | 81.0497 |
| 1 | EXIT_FIXED_R_ONLY | 1550 | 38.00 | -0.0500 | 0.9194 | 97.4812 |
| 1 | EXIT_BE_AT_05R | 1550 | 14.52 | -0.1455 | 0.5995 | 230.9729 |
| 1 | EXIT_BE_AT_08R | 1550 | 24.71 | -0.0971 | 0.7925 | 161.4497 |
| 1 | EXIT_BE_AT_10R | 1550 | 29.10 | -0.0874 | 0.8332 | 150.4555 |
| 1 | EXIT_PARTIAL_50_AT_05R_REST_15R | 1550 | 38.00 | -0.0474 | 0.8891 | 90.4922 |
| 1 | EXIT_PARTIAL_50_AT_10R_REST_15R | 1550 | 38.00 | -0.0489 | 0.9067 | 90.7401 |
| 1 | EXIT_TP_12R_FIXED | 1550 | 43.35 | -0.0462 | 0.9185 | 92.0000 |
| 1 | EXIT_TP_15R_FIXED | 1550 | 38.00 | -0.0500 | 0.9194 | 97.4812 |

## Top MaxPos2 Candidate Rows >= 100 Trades
| Candidate | Mode | Trades | Win% | ExpectancyR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_FIXED_R_ONLY | 128 | 46.88 | 0.1716 | 1.3231 | 12.4998 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_15R_FIXED | 128 | 46.88 | 0.1716 | 1.3231 | 12.4998 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 172 | 45.93 | 0.1480 | 1.2738 | 11.0053 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 172 | 45.93 | 0.1480 | 1.2738 | 11.0053 |
| C_countertrend_pattern_adx_middle | EXIT_FIXED_R_ONLY | 402 | 45.02 | 0.1255 | 1.2283 | 16.9978 |
| C_countertrend_pattern_adx_middle | EXIT_TP_15R_FIXED | 402 | 45.02 | 0.1255 | 1.2283 | 16.9978 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_10R | 128 | 39.84 | 0.1052 | 1.2137 | 12.0034 |
| C_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 402 | 45.02 | 0.1026 | 1.2229 | 12.2499 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_10R_REST_15R | 128 | 46.88 | 0.0936 | 1.1902 | 12.2544 |
| I_entry_open_0_countertrend_break_high | EXIT_FIXED_R_ONLY | 351 | 43.30 | 0.0825 | 1.1455 | 28.5073 |
| I_entry_open_0_countertrend_break_high | EXIT_TP_15R_FIXED | 351 | 43.30 | 0.0825 | 1.1455 | 28.5073 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_10R_REST_15R | 172 | 45.93 | 0.0798 | 1.1615 | 10.5027 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_BE_AT_08R | 128 | 35.94 | 0.0778 | 1.1689 | 13.5134 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 402 | 35.82 | 0.0770 | 1.1674 | 12.4997 |
| C_countertrend_pattern_adx_middle | EXIT_PARTIAL_50_AT_05R_REST_15R | 402 | 45.02 | 0.0758 | 1.2025 | 10.0032 |
| H_entry_open_0_countertrend_pattern_adx_middle | EXIT_BE_AT_10R | 172 | 37.79 | 0.0724 | 1.1465 | 11.0057 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_PARTIAL_50_AT_05R_REST_15R | 128 | 46.88 | 0.0721 | 1.1819 | 9.2499 |
| C_countertrend_pattern_adx_middle | EXIT_BE_AT_08R | 402 | 31.84 | 0.0696 | 1.1705 | 13.0000 |
| C_countertrend_pattern_adx_middle | EXIT_TP_12R_FIXED | 402 | 48.51 | 0.0672 | 1.1304 | 13.2000 |
| J_entry_open_0_countertrend_pattern_adx_middle_break_high | EXIT_TP_12R_FIXED | 128 | 48.44 | 0.0656 | 1.1273 | 10.8000 |

## Artifacts
| Artifact | Path |
| --- | --- |
| MaxPos2 diagnostics | [maxpos2/diagnostics.csv](./maxpos2/diagnostics.csv) |
| MaxPos2 exit simulation | [maxpos2/exit_simulation.csv](./maxpos2/exit_simulation.csv) |
| MaxPos1 diagnostics | [maxpos1/diagnostics.csv](./maxpos1/diagnostics.csv) |
| MaxPos1 exit simulation | [maxpos1/exit_simulation.csv](./maxpos1/exit_simulation.csv) |
| Exit mode summary | [exit_mode_summary.csv](./exit_mode_summary.csv) |
| Candidate filter x modes | [candidate_filter_exit_modes.csv](./candidate_filter_exit_modes.csv) |
| Tag breakdowns by mode | [tag_breakdowns_by_exit_mode.csv](./tag_breakdowns_by_exit_mode.csv) |

## Readout
- MaxPos2 best all-trade mode is `EXIT_FIXED_R_ONLY` with expectancy `-0.0371R`, PF `0.9397`.
- MaxPos1 best all-trade mode is `EXIT_PARTIAL_50_AT_05R_REST_15R` with expectancy `-0.0641R`, PF `0.8532`.
- User focus G (`EntryOpenCount=0 + CounterTrend + BE_AT_10R`) has `466` trades, expectancy `0.0030R`, PF `1.0061`.
- User focus H (`EntryOpenCount=0 + CounterTrend + PatternADX=middle + BE_AT_10R`) has `172` trades, expectancy `0.0724R`, PF `1.1465`.
- Four-condition focus J (`EntryOpenCount=0 + CounterTrend + PatternADX=middle + BreakStrength=high + BE_AT_10R`) has `128` trades, expectancy `0.1052R`, PF `1.2137`.
- This is still diagnostic evidence only. No exit rule is promoted or wired into live trading.
