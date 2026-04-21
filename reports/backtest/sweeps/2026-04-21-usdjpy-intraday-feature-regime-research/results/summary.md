# USDJPY Intraday Feature / Regime Research

- Generated: `2026-04-21T16:03:27`
- Families: `external_sweep, local_sweep, n_wave, session_box`
- Closed trades: `3696`

## Design Plan

- target families:
  - `session_box`
  - `local_sweep`
  - `external_sweep`
  - `n_wave`
- priority feature groups:
  - time / session buckets
  - previous-day / M30 alignment
  - size / breakout-strength buckets
  - trigger / subtype / invalidation line type
  - acceptance / time-stop / runner behavior
- method:
  - trade-level telemetry reconstruction
  - univariate feature tables
  - bivariate feature tables
  - OOS / actual repeatability checks
  - no new EA family, no rescue filters, no ML

## Family Aggregate

| family | window | trades | pf | net | expected_payoff | avg_r | acceptance_exit_rate | time_stop_rate | runner_hit_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| external_sweep | actual | 279 | 0.2923 | -3033.0400 | -10.8711 | -0.3190 | 50.9000 | 18.6400 | 13.6200 |
| external_sweep | oos | 14 | 1.3765 | 28.2100 | 2.0150 | 0.0583 | 28.5700 | 42.8600 | 0.0000 |
| external_sweep | train | 153 | 0.2020 | -2233.5000 | -14.5980 | -0.4306 | 54.9000 | 15.6900 | 12.4200 |
| local_sweep | actual | 1117 | 0.3966 | -7322.9300 | -6.5559 | -0.2025 | 37.2400 | 45.0300 | 6.1800 |
| local_sweep | oos | 93 | 0.5818 | -422.4300 | -4.5423 | -0.1339 | 29.0300 | 53.7600 | 1.0800 |
| local_sweep | train | 672 | 0.3743 | -4590.6800 | -6.8314 | -0.2061 | 38.6900 | 46.5800 | 5.0600 |
| n_wave | actual | 485 | 0.3483 | -2579.4900 | -5.3185 | -0.1587 | 65.5700 | 14.4300 | 7.0100 |
| n_wave | oos | 17 | 0.1902 | -112.6500 | -6.6265 | -0.1914 | 88.2400 | 0.0000 | 11.7600 |
| n_wave | train | 312 | 0.3290 | -1783.4600 | -5.7162 | -0.1683 | 66.0300 | 13.1400 | 6.7300 |
| session_box | actual | 304 | 0.6517 | -390.7500 | -1.2854 | -0.0379 | 62.5000 | 15.7900 | 4.9300 |
| session_box | oos | 55 | 0.9486 | -7.1800 | -0.1305 | -0.0037 | 36.3600 | 25.4500 | 5.4500 |
| session_box | train | 195 | 0.4556 | -464.0000 | -2.3795 | -0.0710 | 76.9200 | 10.2600 | 5.1300 |

## Top Univariate Features

| family | feature_name | feature_value | oos_trades | oos_pf | oos_net | actual_trades | actual_pf | actual_net | actual_acceptance_exit_rate | actual_time_stop_rate | actual_runner_hit_rate | sparse_survivor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| session_box | entry_session_bucket | tokyo_to_london | 12.0000 | 4.5371 | 32.4000 | 76.0000 | 1.3056 | 61.2300 | 46.0500 | 26.3200 | 5.2600 | False |
| session_box | london_timing_bucket | 30_60m | 14.0000 | 0.2169 | -34.7400 | 38.0000 | 2.4092 | 97.3500 | 36.8400 | 21.0500 | 10.5300 | False |
| session_box | weekday | Thu | 15.0000 | 0.2448 | -45.3100 | 79.0000 | 1.8604 | 174.1000 | 40.5100 | 22.7800 | 12.6600 | False |
| session_box | size_bucket | narrow | 19.0000 | 1.5496 | 21.5600 | 85.0000 | 0.9488 | -14.9600 | 48.2400 | 16.4700 | 9.4100 | False |
| session_box | prev_day_alignment_type | far_prev_day_high | 25.0000 | 2.9014 | 53.4300 | 155.0000 | 0.7758 | -126.2100 | 63.8700 | 14.1900 | 8.3900 | False |
| session_box | breakout_side | high_breakout | 31.0000 | 1.9499 | 41.1700 | 180.0000 | 0.7580 | -155.8300 | 64.4400 | 13.8900 | 8.3300 | False |
| session_box | subtype | session_high_breakout | 31.0000 | 1.9499 | 41.1700 | 180.0000 | 0.7580 | -155.8300 | 64.4400 | 13.8900 | 8.3300 | False |
| session_box | weekday | Tue | 7.0000 | 5.1177 | 29.7300 | 59.0000 | 0.7502 | -47.5600 | 64.4100 | 13.5600 | 3.3900 | False |
| session_box | entry_strength_bucket | medium | 12.0000 | 0.9725 | -0.9400 | 118.0000 | 0.7444 | -122.0500 | 68.6400 | 14.4100 | 6.7800 | False |
| session_box | entry_strength_bucket | strong | 41.0000 | 1.1194 | 10.5800 | 122.0000 | 0.7238 | -102.7300 | 47.5400 | 18.8500 | 4.1000 | False |
| session_box | trigger_type | range_close_confirm | 36.0000 | 1.3114 | 23.9400 | 164.0000 | 0.7221 | -153.5600 | 57.3200 | 17.6800 | 5.4900 | False |
| session_box | m30_swing_alignment_type | far_m30_prior_swing_high | 31.0000 | 1.9499 | 41.1700 | 159.0000 | 0.6733 | -188.6200 | 66.6700 | 12.5800 | 8.1800 | False |
| session_box | size_bucket | normal | 26.0000 | 0.6924 | -22.7900 | 154.0000 | 0.6640 | -185.2200 | 62.3400 | 16.2300 | 3.9000 | False |
| external_sweep | weekday | Tue | 7.0000 | 1.5714 | 12.1600 | 60.0000 | 0.6465 | -176.3800 | 43.3300 | 25.0000 | 11.6700 | False |
| session_box | entry_session_bucket | london_mid | 19.0000 | 0.9284 | -3.9100 | 86.0000 | 0.6067 | -119.3900 | 62.7900 | 22.0900 | 2.3300 | False |
| session_box | london_timing_bucket | 0_30m | 12.0000 | 3.1992 | 36.8800 | 67.0000 | 0.5949 | -94.5400 | 61.1900 | 22.3900 | 1.4900 | False |
| external_sweep | entry_session_bucket | london_mid | 5.0000 | 0.0000 | 33.4400 | 45.0000 | 0.5917 | -135.2500 | 40.0000 | 22.2200 | 11.1100 | False |
| session_box | trigger_type | range_retest_confirm | 19.0000 | 0.5041 | -31.1200 | 140.0000 | 0.5834 | -237.1900 | 68.5700 | 13.5700 | 4.2900 | False |
| local_sweep | weekday | Thu | 5.0000 | 1.7993 | 25.8100 | 228.0000 | 0.5601 | -939.6100 | 38.1600 | 47.3700 | 6.5800 | False |
| local_sweep | entry_session_bucket | ny_late | 30.0000 | 1.1080 | 20.8400 | 309.0000 | 0.5590 | -1169.5600 | 35.6000 | 51.7800 | 8.0900 | False |

## Top Bivariate Feature Bundles

| family | feature_name | feature_value | oos_trades | oos_pf | oos_net | actual_trades | actual_pf | actual_net | actual_acceptance_exit_rate | actual_time_stop_rate | actual_runner_hit_rate | sparse_survivor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| session_box | london_timing_bucket x breakout_side | 0_30m \| low_breakout | 6.0000 | 1.5927 | 9.9400 | 28.0000 | 1.4148 | 30.4800 | 42.8600 | 42.8600 | 0.0000 | False |
| session_box | entry_session_bucket x london_timing_bucket | tokyo_to_london \| 30_60m | 5.0000 | 0.2773 | -6.6200 | 24.0000 | 6.5989 | 129.1100 | 20.8300 | 29.1700 | 16.6700 | False |
| session_box | london_timing_bucket x breakout_side | 30_60m \| high_breakout | 10.0000 | 0.6312 | -5.6200 | 22.0000 | 4.4461 | 98.4200 | 31.8200 | 31.8200 | 18.1800 | False |
| session_box | trigger_type x entry_strength_bucket | range_close_confirm \| medium | 8.0000 | 3.4989 | 22.8900 | 62.0000 | 0.8952 | -24.5800 | 66.1300 | 12.9000 | 9.6800 | False |
| session_box | breakout_side x trigger_type | high_breakout \| range_retest_confirm | 10.0000 | 3.7625 | 21.0500 | 82.0000 | 0.8016 | -61.5800 | 67.0700 | 14.6300 | 7.3200 | False |
| session_box | trigger_type x entry_strength_bucket | range_close_confirm \| strong | 26.0000 | 1.3511 | 17.8700 | 70.0000 | 0.7856 | -39.9500 | 35.7100 | 25.7100 | 2.8600 | False |
| session_box | prev_day_alignment_type x breakout_side | far_prev_day_high \| high_breakout | 25.0000 | 2.9014 | 53.4300 | 155.0000 | 0.7758 | -126.2100 | 63.8700 | 14.1900 | 8.3900 | False |
| session_box | breakout_side x trigger_type | low_breakout \| range_close_confirm | 15.0000 | 1.0928 | 3.8200 | 66.0000 | 0.7293 | -59.3100 | 50.0000 | 24.2400 | 0.0000 | False |
| session_box | breakout_side x trigger_type | high_breakout \| range_close_confirm | 21.0000 | 1.5633 | 20.1200 | 98.0000 | 0.7173 | -94.2500 | 62.2400 | 13.2700 | 9.1800 | False |
| session_box | london_timing_bucket x breakout_side | 60m_plus \| high_breakout | 15.0000 | 1.7064 | 19.8500 | 119.0000 | 0.7162 | -129.2300 | 67.2300 | 12.6100 | 8.4000 | False |
| session_box | entry_session_bucket x london_timing_bucket | london_mid \| 60m_plus | 11.0000 | 2.3177 | 23.5600 | 75.0000 | 0.6848 | -80.5200 | 61.3300 | 25.3300 | 2.6700 | False |
| session_box | trigger_type x entry_strength_bucket | range_retest_confirm \| strong | 15.0000 | 0.8066 | -7.2900 | 52.0000 | 0.6618 | -62.7800 | 63.4600 | 9.6200 | 5.7700 | False |
| session_box | prev_day_alignment_type x breakout_side | unavailable \| high_breakout | 6.0000 | 0.1955 | -12.2600 | 25.0000 | 0.6338 | -29.6200 | 68.0000 | 12.0000 | 8.0000 | False |
| session_box | entry_session_bucket x london_timing_bucket | tokyo_to_london \| 0_30m | 7.0000 | 0.0000 | 39.0200 | 52.0000 | 0.6172 | -67.8800 | 57.6900 | 25.0000 | 0.0000 | False |
| external_sweep | entry_session_bucket x london_timing_bucket | london_mid \| 60m_plus | 5.0000 | 0.0000 | 33.4400 | 45.0000 | 0.5917 | -135.2500 | 40.0000 | 22.2200 | 11.1100 | False |
| session_box | entry_session_bucket x london_timing_bucket | london_open \| 60m_plus | 11.0000 | 0.3505 | -28.4500 | 75.0000 | 0.5869 | -129.8000 | 69.3300 | 4.0000 | 10.6700 | False |
| local_sweep | entry_session_bucket x london_timing_bucket | ny_late \| 60m_plus | 30.0000 | 1.1080 | 20.8400 | 309.0000 | 0.5590 | -1169.5600 | 35.6000 | 51.7800 | 8.0900 | False |
| session_box | prev_day_alignment_type x breakout_side | far_prev_day_low \| low_breakout | 24.0000 | 0.4979 | -48.3500 | 101.0000 | 0.5457 | -184.5900 | 58.4200 | 21.7800 | 0.0000 | False |
| n_wave | entry_session_bucket x london_timing_bucket | ny_late \| 60m_plus | 7.0000 | 0.6266 | -15.7700 | 120.0000 | 0.4677 | -453.4900 | 65.8300 | 17.5000 | 7.5000 | False |
| local_sweep | trigger_type x entry_strength_bucket | recent_swing_breakdown \| weak | 12.0000 | 1.6752 | 47.5900 | 70.0000 | 0.4617 | -484.3800 | 34.2900 | 42.8600 | 10.0000 | False |

## Repeatability Table

| family | feature_name | feature_value | pf_repeat | oos_actual_same_direction_positive | oos_trades | oos_pf | actual_trades | actual_pf | actual_acceptance_exit_rate | actual_time_stop_rate | actual_runner_hit_rate | sparse_survivor | time_stop_reliant |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| session_box | london_timing_bucket x breakout_side | 0_30m \| low_breakout | True | True | 6.0000 | 1.5927 | 28.0000 | 1.4148 | 42.8600 | 42.8600 | 0.0000 | False | True |
| session_box | entry_session_bucket | tokyo_to_london | True | True | 12.0000 | 4.5371 | 76.0000 | 1.3056 | 46.0500 | 26.3200 | 5.2600 | False | False |
| external_sweep | subtype | context_prior_swing | False | True | 5.0000 | 0.0000 | 7.0000 | 1.1204 | 28.5700 | 42.8600 | 0.0000 | True | True |
| external_sweep | trigger_type x entry_strength_bucket | retest_failure \| strong | False | True | 1.0000 | 0.0000 | 7.0000 | 1.0168 | 28.5700 | 28.5700 | 28.5700 | True | False |
| session_box | entry_session_bucket x london_timing_bucket | ny_overlap \| 0_30m | False | True | 1.0000 | 0.0000 | 1.0000 | 0.0000 | 0.0000 | 0.0000 | 100.0000 | True | False |
| session_box | entry_session_bucket x london_timing_bucket | tokyo_to_london \| 30_60m | False | False | 5.0000 | 0.2773 | 24.0000 | 6.5989 | 20.8300 | 29.1700 | 16.6700 | False | False |
| session_box | london_timing_bucket x breakout_side | 30_60m \| high_breakout | False | False | 10.0000 | 0.6312 | 22.0000 | 4.4461 | 31.8200 | 31.8200 | 18.1800 | False | False |
| n_wave | subtype x invalidation_line_type | double_top_wave2 \| wave1_low | False | False | nan | nan | 16.0000 | 3.0741 | 37.5000 | 31.2500 | 18.7500 | True | False |
| session_box | london_timing_bucket | 30_60m | False | False | 14.0000 | 0.2169 | 38.0000 | 2.4092 | 36.8400 | 21.0500 | 10.5300 | False | False |
| session_box | weekday | Thu | False | False | 15.0000 | 0.2448 | 79.0000 | 1.8604 | 40.5100 | 22.7800 | 12.6600 | False | False |
| local_sweep | london_timing_bucket | 0_30m | False | False | nan | nan | 12.0000 | 1.5713 | 8.3300 | 91.6700 | 0.0000 | True | True |
| local_sweep | entry_session_bucket x london_timing_bucket | tokyo_to_london \| 0_30m | False | False | nan | nan | 12.0000 | 1.5713 | 8.3300 | 91.6700 | 0.0000 | True | True |
| session_box | m30_swing_alignment_type | near_m30_prior_swing_high | False | False | nan | nan | 21.0000 | 1.4934 | 47.6200 | 23.8100 | 9.5200 | False | False |
| external_sweep | london_timing_bucket | 0_30m | False | False | nan | nan | 7.0000 | 0.9789 | 28.5700 | 14.2900 | 28.5700 | True | False |
| external_sweep | entry_session_bucket x london_timing_bucket | tokyo_to_london \| 0_30m | False | False | nan | nan | 7.0000 | 0.9789 | 28.5700 | 14.2900 | 28.5700 | True | False |
| session_box | london_timing_bucket x breakout_side | 30_60m \| low_breakout | False | False | 4.0000 | 0.0000 | 16.0000 | 0.9736 | 43.7500 | 6.2500 | 0.0000 | True | False |
| session_box | size_bucket | narrow | False | False | 19.0000 | 1.5496 | 85.0000 | 0.9488 | 48.2400 | 16.4700 | 9.4100 | False | False |
| session_box | trigger_type x entry_strength_bucket | range_close_confirm \| medium | False | False | 8.0000 | 3.4989 | 62.0000 | 0.8952 | 66.1300 | 12.9000 | 9.6800 | False | False |
| session_box | breakout_side x trigger_type | high_breakout \| range_retest_confirm | False | False | 10.0000 | 3.7625 | 82.0000 | 0.8016 | 67.0700 | 14.6300 | 7.3200 | False | False |
| session_box | trigger_type x entry_strength_bucket | range_close_confirm \| strong | False | False | 26.0000 | 1.3511 | 70.0000 | 0.7856 | 35.7100 | 25.7100 | 2.8600 | False | False |

## Feature Bundle Candidates

- no data

## Acceptance-Dominant Regimes

| family | feature_name | feature_value | actual_trades | actual_pf | actual_net | actual_acceptance_exit_rate | actual_time_stop_rate | actual_runner_hit_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| session_box | trigger_type x entry_strength_bucket | range_close_confirm \| weak | 32.0000 | 0.3233 | -89.0300 | 87.5000 | 9.3800 | 3.1200 |
| n_wave | subtype | lower_high_wave2 | 58.0000 | 0.1733 | -364.6700 | 82.7600 | 15.5200 | 1.7200 |
| n_wave | subtype x invalidation_line_type | lower_high_wave2 \| wave1_low | 58.0000 | 0.1733 | -364.6700 | 82.7600 | 15.5200 | 1.7200 |
| session_box | size_bucket | wide | 65.0000 | 0.3154 | -190.5700 | 81.5400 | 13.8500 | 1.5400 |
| n_wave | trigger_type x entry_strength_bucket | recent_swing_breakdown \| medium | 85.0000 | 0.2090 | -470.1500 | 81.1800 | 5.8800 | 7.0600 |
| external_sweep | trigger_type x entry_strength_bucket | retest_failure \| medium | 20.0000 | 0.4213 | -150.8100 | 80.0000 | 0.0000 | 10.0000 |
| session_box | entry_strength_bucket | weak | 64.0000 | 0.3906 | -165.9700 | 79.6900 | 12.5000 | 3.1200 |
| n_wave | entry_session_bucket | london_mid | 72.0000 | 0.4480 | -314.2300 | 79.1700 | 1.3900 | 8.3300 |
| n_wave | entry_session_bucket x london_timing_bucket | london_mid \| 60m_plus | 72.0000 | 0.4480 | -314.2300 | 79.1700 | 1.3900 | 8.3300 |
| n_wave | trigger_type | recent_swing_breakdown | 274.0000 | 0.2648 | -1485.4700 | 78.1000 | 9.8500 | 4.0100 |
| n_wave | trigger_type x entry_strength_bucket | recent_swing_breakdown \| weak | 113.0000 | 0.3645 | -541.1700 | 77.8800 | 9.7300 | 2.6500 |
| session_box | weekday | Fri | 56.0000 | 0.1329 | -220.3400 | 76.7900 | 10.7100 | 1.7900 |
| n_wave | size_bucket | wide | 120.0000 | 0.2647 | -695.1400 | 76.6700 | 14.1700 | 2.5000 |
| session_box | entry_session_bucket x london_timing_bucket | ny_overlap \| 60m_plus | 49.0000 | 0.2663 | -183.2400 | 75.5100 | 6.1200 | 0.0000 |
| n_wave | trigger_type x entry_strength_bucket | recent_swing_breakdown \| strong | 76.0000 | 0.1747 | -474.1500 | 75.0000 | 14.4700 | 2.6300 |
| session_box | london_timing_bucket x breakout_side | 0_30m \| high_breakout | 39.0000 | 0.2182 | -125.0200 | 74.3600 | 7.6900 | 2.5600 |
| n_wave | weekday | Wed | 116.0000 | 0.2397 | -743.9900 | 73.2800 | 9.4800 | 5.1700 |
| n_wave | entry_session_bucket | other | 29.0000 | 0.0674 | -244.7000 | 72.4100 | 13.7900 | 3.4500 |
| n_wave | entry_session_bucket x london_timing_bucket | other \| 60m_plus | 29.0000 | 0.0674 | -244.7000 | 72.4100 | 13.7900 | 3.4500 |
| session_box | trigger_type x entry_strength_bucket | range_retest_confirm \| weak | 32.0000 | 0.4535 | -76.9400 | 71.8800 | 15.6200 | 3.1200 |

## Time-Stop-Reliant Regimes

| family | feature_name | feature_value | actual_trades | actual_pf | actual_net | actual_time_stop_rate | actual_time_stop_after_partial_rate | actual_runner_hit_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| local_sweep | entry_session_bucket | tokyo_to_london | 34.0000 | 0.5412 | -115.0600 | 64.7100 | 5.8800 | 2.9400 |
| local_sweep | size_bucket | wide | 263.0000 | 0.3683 | -1794.2500 | 60.4600 | 1.5200 | 1.1400 |
| local_sweep | trigger_type x entry_strength_bucket | recent_swing_breakdown \| strong | 153.0000 | 0.3548 | -1061.2600 | 52.2900 | 3.9200 | 4.5800 |
| local_sweep | entry_session_bucket | ny_late | 309.0000 | 0.5590 | -1169.5600 | 51.7800 | 4.2100 | 8.0900 |
| local_sweep | entry_session_bucket x london_timing_bucket | ny_late \| 60m_plus | 309.0000 | 0.5590 | -1169.5600 | 51.7800 | 4.2100 | 8.0900 |
| local_sweep | trigger_type x entry_strength_bucket | recent_swing_breakdown \| medium | 131.0000 | 0.3742 | -808.4400 | 51.1500 | 3.8200 | 6.8700 |
| local_sweep | entry_session_bucket | london_mid | 132.0000 | 0.4509 | -677.2900 | 50.7600 | 6.8200 | 6.0600 |
| local_sweep | entry_session_bucket x london_timing_bucket | london_mid \| 60m_plus | 132.0000 | 0.4509 | -677.2900 | 50.7600 | 6.8200 | 6.0600 |
| local_sweep | trigger_type x entry_strength_bucket | reclaim_close_confirm \| medium | 314.0000 | 0.4140 | -1839.9000 | 50.6400 | 4.4600 | 6.3700 |
| local_sweep | trigger_type | recent_swing_breakdown | 354.0000 | 0.3864 | -2354.0800 | 50.0000 | 3.9500 | 6.5000 |
| local_sweep | entry_session_bucket | other | 98.0000 | 0.1907 | -1099.7100 | 50.0000 | 1.0200 | 4.0800 |
| local_sweep | entry_session_bucket x london_timing_bucket | other \| 60m_plus | 98.0000 | 0.1907 | -1099.7100 | 50.0000 | 1.0200 | 4.0800 |
| local_sweep | london_timing_bucket | 30_60m | 22.0000 | 0.2658 | -145.2800 | 50.0000 | 0.0000 | 4.5500 |
| local_sweep | entry_session_bucket x london_timing_bucket | tokyo_to_london \| 30_60m | 22.0000 | 0.2658 | -145.2800 | 50.0000 | 0.0000 | 4.5500 |
| local_sweep | entry_strength_bucket | medium | 488.0000 | 0.4314 | -2800.4400 | 48.5700 | 4.3000 | 5.9400 |
| local_sweep | weekday | Mon | 158.0000 | 0.4268 | -864.1200 | 48.1000 | 2.5300 | 3.8000 |
| local_sweep | weekday | Thu | 228.0000 | 0.5601 | -939.6100 | 47.3700 | 3.0700 | 6.5800 |
| local_sweep | weekday | Fri | 282.0000 | 0.4051 | -1828.3300 | 47.1600 | 3.1900 | 9.5700 |
| local_sweep | trigger_type | reclaim_close_confirm | 657.0000 | 0.3949 | -4172.3200 | 46.1200 | 3.6500 | 6.5400 |
| local_sweep | london_timing_bucket | 60m_plus | 793.0000 | 0.4089 | -5188.7000 | 45.9000 | 3.9100 | 6.3100 |

## Runner-Friendly Regimes

| family | feature_name | feature_value | actual_trades | actual_pf | actual_net | actual_runner_hit_rate | actual_time_stop_rate | actual_acceptance_exit_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| external_sweep | size_bucket | narrow | 76.0000 | 0.5388 | -590.0700 | 23.6800 | 23.6800 | 32.8900 |
| external_sweep | weekday | Fri | 36.0000 | 0.1538 | -1029.1600 | 19.4400 | 27.7800 | 38.8900 |
| external_sweep | weekday | Mon | 47.0000 | 0.2403 | -526.6400 | 19.1500 | 6.3800 | 63.8300 |
| external_sweep | trigger_type x entry_strength_bucket | reclaim_close_confirm \| strong | 27.0000 | 0.7853 | -54.3100 | 18.5200 | 40.7400 | 29.6300 |
| external_sweep | entry_strength_bucket | strong | 71.0000 | 0.6999 | -203.1600 | 18.3100 | 33.8000 | 36.6200 |
| session_box | london_timing_bucket x breakout_side | 30_60m \| high_breakout | 22.0000 | 4.4461 | 98.4200 | 18.1800 | 31.8200 | 31.8200 |
| session_box | entry_session_bucket x london_timing_bucket | tokyo_to_london \| 30_60m | 24.0000 | 6.5989 | 129.1100 | 16.6700 | 29.1700 | 20.8300 |
| external_sweep | entry_session_bucket | tokyo | 36.0000 | 0.6324 | -112.0500 | 16.6700 | 36.1100 | 27.7800 |
| external_sweep | london_timing_bucket | pre_london | 36.0000 | 0.6324 | -112.0500 | 16.6700 | 36.1100 | 27.7800 |
| external_sweep | entry_session_bucket x london_timing_bucket | tokyo \| pre_london | 36.0000 | 0.6324 | -112.0500 | 16.6700 | 36.1100 | 27.7800 |
| external_sweep | trigger_type x entry_strength_bucket | recent_swing_breakdown \| medium | 30.0000 | 0.5958 | -102.7400 | 16.6700 | 26.6700 | 33.3300 |
| external_sweep | trigger_type | recent_swing_breakdown | 86.0000 | 0.3537 | -743.1300 | 16.2800 | 23.2600 | 40.7000 |
| external_sweep | trigger_type x entry_strength_bucket | recent_swing_breakdown \| strong | 37.0000 | 0.5581 | -150.2600 | 16.2200 | 29.7300 | 43.2400 |
| n_wave | trigger_type x entry_strength_bucket | invalidation_close_break \| strong | 38.0000 | 0.4909 | -160.2700 | 15.7900 | 21.0500 | 52.6300 |
| external_sweep | subtype | previous_day_extreme | 234.0000 | 0.2889 | -2634.2900 | 14.9600 | 17.9500 | 52.1400 |
| external_sweep | weekday | Thu | 42.0000 | 0.5314 | -235.2300 | 14.2900 | 19.0500 | 54.7600 |
| external_sweep | trigger_type x entry_strength_bucket | reclaim_close_confirm \| medium | 64.0000 | 0.2389 | -836.0600 | 14.0600 | 9.3800 | 57.8100 |
| external_sweep | entry_strength_bucket | medium | 114.0000 | 0.3246 | -1089.6100 | 14.0400 | 12.2800 | 55.2600 |
| external_sweep | entry_session_bucket | ny_late | 104.0000 | 0.3323 | -1056.7300 | 13.4600 | 5.7700 | 66.3500 |
| external_sweep | entry_session_bucket x london_timing_bucket | ny_late \| 60m_plus | 104.0000 | 0.3323 | -1056.7300 | 13.4600 | 5.7700 | 66.3500 |
