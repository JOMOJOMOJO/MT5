# Fixed research tables

Only JOURNAL_CLEAN_REAL_TICK labels are used by models. No filter adoption.

## baseline_statistics

| scope | n | tp_rate | expectancy_R | pf |
| --- | --- | --- | --- | --- |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 180 | 0.4167 | -0.1208 | 0.8054 |
| JOURNAL_CLEAN_REAL_TICK | 82 | 0.4146 | -0.1151 | 0.8121 |

## monthly_statistics

| scope | month | tp | sl | n | tp_rate | expectancy_R | pf |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-01 | 6 | 6 | 12 | 0.5000 | -0.0878 | 0.8723 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-02 | 5 | 7 | 12 | 0.4167 | -0.0851 | 0.8548 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-03 | 5 | 15 | 20 | 0.2500 | -0.4678 | 0.3902 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-04 | 8 | 5 | 13 | 0.6154 | 0.3317 | 1.8166 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-05 | 6 | 11 | 17 | 0.3529 | -0.2465 | 0.6317 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-06 | 2 | 5 | 7 | 0.2857 | -0.3785 | 0.4761 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-07 | 10 | 8 | 18 | 0.5556 | 0.1585 | 1.3118 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-08 | 10 | 6 | 16 | 0.6250 | 0.3551 | 1.8996 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-09 | 3 | 9 | 12 | 0.2500 | -0.4838 | 0.3826 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-10 | 9 | 14 | 23 | 0.3913 | -0.1622 | 0.7432 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-11 | 6 | 10 | 16 | 0.3750 | -0.2007 | 0.6917 |
| ALL_TESTER_OBSERVED_NOT_VERIFIED | 2024-12 | 5 | 9 | 14 | 0.3571 | -0.2554 | 0.6270 |
| JOURNAL_CLEAN_REAL_TICK | 2024-01 | 0 | 0 | 0 | NA | NA | NA |
| JOURNAL_CLEAN_REAL_TICK | 2024-02 | 0 | 0 | 0 | NA | NA | NA |
| JOURNAL_CLEAN_REAL_TICK | 2024-03 | 0 | 0 | 0 | NA | NA | NA |
| JOURNAL_CLEAN_REAL_TICK | 2024-04 | 0 | 0 | 0 | NA | NA | NA |
| JOURNAL_CLEAN_REAL_TICK | 2024-05 | 0 | 0 | 0 | NA | NA | NA |
| JOURNAL_CLEAN_REAL_TICK | 2024-06 | 0 | 0 | 0 | NA | NA | NA |
| JOURNAL_CLEAN_REAL_TICK | 2024-07 | 1 | 0 | 1 | 1.0000 | 1.2000 | NA |
| JOURNAL_CLEAN_REAL_TICK | 2024-08 | 10 | 6 | 16 | 0.6250 | 0.3551 | 1.8996 |
| JOURNAL_CLEAN_REAL_TICK | 2024-09 | 3 | 9 | 12 | 0.2500 | -0.4838 | 0.3826 |
| JOURNAL_CLEAN_REAL_TICK | 2024-10 | 9 | 14 | 23 | 0.3913 | -0.1622 | 0.7432 |
| JOURNAL_CLEAN_REAL_TICK | 2024-11 | 6 | 10 | 16 | 0.3750 | -0.2007 | 0.6917 |
| JOURNAL_CLEAN_REAL_TICK | 2024-12 | 5 | 9 | 14 | 0.3571 | -0.2554 | 0.6270 |

## walkforward_fold_status

| fold | test_start | test_end | raw_train | train_n | test_n | train_tp | test_tp | purged | status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| train_Jan_04_test_05_06 | 2024-05-01 00:00:00 | 2024-07-01 00:00:00 | 0 | 0 | 0 | 0 | 0 | 0 | INSUFFICIENT_VERIFIED_LABELS |
| train_Jan_06_test_07_08 | 2024-07-01 00:00:00 | 2024-09-01 00:00:00 | 0 | 0 | 17 | 0 | 11 | 0 | INSUFFICIENT_VERIFIED_LABELS |
| train_Jan_08_test_09_10 | 2024-09-01 00:00:00 | 2024-11-01 00:00:00 | 17 | 17 | 35 | 11 | 12 | 0 | INSUFFICIENT_VERIFIED_LABELS |
| train_Jan_10_test_11_12 | 2024-11-01 00:00:00 | 2025-01-01 00:00:00 | 52 | 52 | 30 | 23 | 11 | 0 | EVALUATED |

## walkforward_metrics

| fold | model | train_n | test_n | roc_auc | pr_auc | pr_auc_trapezoid | average_precision | balanced_accuracy | brier |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| train_Jan_10_test_11_12 | TRAIN_PREVALENCE | 52 | 30 | 0.5000 | 0.3667 | 0.6833 | 0.3667 | 0.5000 | 0.2379 |
| train_Jan_10_test_11_12 | LOGISTIC_L2 | 52 | 30 | 0.4115 | 0.3511 | 0.3129 | 0.3511 | 0.4330 | 0.2937 |
| train_Jan_10_test_11_12 | TREE_D2 | 52 | 30 | 0.6579 | 0.5870 | 0.6714 | 0.5870 | 0.5550 | 0.2482 |
| train_Jan_10_test_11_12 | TREE_D3 | 52 | 30 | 0.6579 | 0.5870 | 0.6714 | 0.5870 | 0.5550 | 0.2482 |
| train_Jan_10_test_11_12 | TREE_D4 | 52 | 30 | 0.6579 | 0.5870 | 0.6714 | 0.5870 | 0.5550 | 0.2482 |
| train_Jan_10_test_11_12 | LIGHTGBM | 52 | 30 | 0.5574 | 0.5092 | 0.4837 | 0.5092 | 0.5766 | 0.2344 |

## htf_group_importance

| fold | model | group | auc_drop_mean | auc_drop_std |
| --- | --- | --- | --- | --- |
| train_Jan_10_test_11_12 | LOGISTIC_L2 | HTF_BOTH | -0.1012 | 0.0520 |
| train_Jan_10_test_11_12 | LOGISTIC_L2 | H1 | -0.0447 | 0.0340 |
| train_Jan_10_test_11_12 | LOGISTIC_L2 | M15 | -0.0498 | 0.0437 |
| train_Jan_10_test_11_12 | TREE_D2 | HTF_BOTH | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D2 | H1 | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D2 | M15 | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D3 | HTF_BOTH | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D3 | H1 | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D3 | M15 | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D4 | HTF_BOTH | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D4 | H1 | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | TREE_D4 | M15 | 0.0000 | 0.0000 |
| train_Jan_10_test_11_12 | LIGHTGBM | HTF_BOTH | -0.1266 | 0.0716 |
| train_Jan_10_test_11_12 | LIGHTGBM | H1 | -0.0639 | 0.0475 |
| train_Jan_10_test_11_12 | LIGHTGBM | M15 | -0.0805 | 0.0458 |

## cluster_quality

| fold | k | train_silhouette | test_silhouette | minimum_train_cluster | seed_ari_mean | temporal_stability |
| --- | --- | --- | --- | --- | --- | --- |
| train_Jan_10_test_11_12 | 2 | 0.2829 | NA | 2 | 0.5046 | NOT_ESTIMABLE_ONE_FOLD |
| train_Jan_10_test_11_12 | 3 | 0.0785 | 0.0047 | 2 | 0.3081 | NOT_ESTIMABLE_ONE_FOLD |
| train_Jan_10_test_11_12 | 4 | 0.0682 | 0.0189 | 2 | 0.3943 | NOT_ESTIMABLE_ONE_FOLD |
| train_Jan_10_test_11_12 | 5 | 0.0611 | 0.0060 | 2 | 0.2870 | NOT_ESTIMABLE_ONE_FOLD |
| train_Jan_10_test_11_12 | 6 | 0.0596 | 0.0091 | 1 | 0.3883 | NOT_ESTIMABLE_ONE_FOLD |

## Prespecified hypothesis features (82 labeled; descriptive)

| feature | outcome | standardized_difference_win_minus_loss | n | mean | median | q25 | q75 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| wave1_er | TP | 0.1536 | 34 | 0.8552 | 0.8702 | 0.7931 | 0.9932 |
| wave1_er | SL | 0.1536 | 48 | 0.8317 | 0.8599 | 0.7283 | 1.0000 |
| wave1_bullish_fraction | TP | 0.0632 | 34 | 0.7342 | 0.7500 | 0.6667 | 0.8182 |
| wave1_bullish_fraction | SL | 0.0632 | 48 | 0.7252 | 0.7386 | 0.6250 | 0.8333 |
| window20_upper25_fraction | TP | 0.0614 | 34 | 0.1912 | 0.1750 | 0.1000 | 0.2875 |
| window20_upper25_fraction | SL | 0.0614 | 48 | 0.1833 | 0.1500 | 0.1000 | 0.2125 |
| m15_up_swing_vs_previous | TP | 0.2651 | 34 | 1.5185 | 1.1235 | 0.7103 | 1.6883 |
| m15_up_swing_vs_previous | SL | 0.2651 | 47 | 1.1821 | 1.0817 | 0.6865 | 1.5731 |
| h1_up_down_swing_ratio | TP | 0.3391 | 34 | 1.4398 | 1.1479 | 0.7320 | 1.5975 |
| h1_up_down_swing_ratio | SL | 0.3391 | 48 | 1.0624 | 0.8614 | 0.5415 | 1.1982 |
| h1_down_swing_vs_previous | TP | -0.3155 | 34 | 1.1472 | 1.0226 | 0.6308 | 1.6525 |
| h1_down_swing_vs_previous | SL | -0.3155 | 48 | 1.4802 | 1.0509 | 0.5995 | 1.8246 |
| wave1_bullish_body_share | TP | -0.0379 | 34 | 0.8099 | 0.8207 | 0.7395 | 0.8710 |
| wave1_bullish_body_share | SL | -0.0379 | 48 | 0.8144 | 0.8034 | 0.7426 | 0.8971 |
| wave1_max_drawdown_formation_atr | TP | -0.1180 | 34 | 0.3626 | 0.3359 | 0.0159 | 0.5116 |
| wave1_max_drawdown_formation_atr | SL | -0.1180 | 48 | 0.4103 | 0.3493 | 0.0000 | 0.5845 |
| wave1_mean_clv | TP | 0.3111 | 34 | 0.6525 | 0.6542 | 0.5998 | 0.6884 |
| wave1_mean_clv | SL | 0.3111 | 48 | 0.6268 | 0.6164 | 0.5646 | 0.6953 |
| wave1_strength_atr_formation | TP | 0.3226 | 34 | 5.6149 | 4.4761 | 3.4429 | 5.8830 |
| wave1_strength_atr_formation | SL | 0.3226 | 48 | 4.4785 | 4.3182 | 3.3757 | 5.5759 |

## LightGBM fixed probability bins

| fold | model | probability_bin | predicted_mean | n | tp_rate | expectancy_R | pf |
| --- | --- | --- | --- | --- | --- | --- | --- |
| train_Jan_10_test_11_12 | LIGHTGBM | <0.35 | 0.3171 | 7 | 0.2857 | -0.3853 | 0.4712 |
| train_Jan_10_test_11_12 | LIGHTGBM | 0.35-0.40 | 0.3861 | 5 | 0.4000 | -0.1328 | 0.7834 |
| train_Jan_10_test_11_12 | LIGHTGBM | 0.40-0.45 | 0.4319 | 4 | 0.5000 | 0.0960 | 1.1905 |
| train_Jan_10_test_11_12 | LIGHTGBM | 0.45-0.50 | 0.4781 | 6 | 0.1667 | -0.7590 | 0.2095 |
| train_Jan_10_test_11_12 | LIGHTGBM | 0.50-0.55 | 0.5216 | 5 | 0.4000 | -0.1266 | 0.7915 |
| train_Jan_10_test_11_12 | LIGHTGBM | 0.55-0.60 | 0.5791 | 2 | 0.5000 | 0.0905 | 1.1778 |
| train_Jan_10_test_11_12 | LIGHTGBM | >=0.60 | 0.6733 | 1 | 1.0000 | 1.1981 | NA |
