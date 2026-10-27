# Wave33 January causal higher-timeframe screen

Frozen-entry exploratory description. No EA launch, optimization, or filter promotion.

## Baselines (entry month)

| Run | Period | Trades | Wins | Losses | Sum R | Net cash |
|---|---|---:|---:|---:|---:|---:|
| gold_v180 | JAN | 28 | 8 | 20 | -9.707 | -469.77 |
| gold_v190 | JAN | 23 | 4 | 18 | -9.499 | -451.27 |
| usd_v180 | JAN | 32 | 11 | 21 | -9.794 | -451.31 |
| usd_v180 | POST_JAN | 48 | 21 | 27 | -2.706 | -142.38 |

## Fixed descriptive screens

18 prespecified threshold flags; all are retained, including negative/null findings. Multiple comparisons and small counts make this hypothesis discovery only.
No p-value or confidence claim is attached. Version runs share entries and are correlated, so they must not be pooled.

| Run/period | Flag | True N (losses) | True mean R | False N (losses) | False mean R | Missing |
|---|---|---:|---:|---:|---:|---:|
| gold_v180/JAN | h1_ema_against | 15 (10) | -0.206 | 11 (9) | -0.613 | 2 |
| gold_v180/JAN | h1_slope_against | 13 (9) | -0.265 | 13 (10) | -0.491 | 2 |
| gold_v180/JAN | h1_momentum_against | 8 (5) | -0.200 | 19 (14) | -0.374 | 1 |
| gold_v180/JAN | h1_range_er12 | 12 (9) | -0.376 | 15 (10) | -0.279 | 1 |
| gold_v180/JAN | h1_previous_body_against | 10 (6) | -0.144 | 18 (14) | -0.459 | 0 |
| gold_v180/JAN | h1_large_rejection_wick | 7 (5) | -0.409 | 21 (15) | -0.326 | 0 |
| gold_v180/JAN | h1_vol_expansion | 0 (0) | NA | 26 (19) | -0.378 | 2 |
| gold_v180/JAN | h1_stretched_from_ema20 | 5 (4) | -0.529 | 21 (15) | -0.342 | 2 |
| gold_v180/JAN | h1_directional_outer_quartile24 | 5 (4) | -0.529 | 21 (15) | -0.342 | 2 |
| gold_v180/JAN | h1_directional_outer_quartile48 | 7 (5) | -0.360 | 19 (14) | -0.385 | 2 |
| gold_v180/JAN | h1_obstacle_inside1r | 9 (5) | -0.032 | 15 (12) | -0.502 | 4 |
| gold_v180/JAN | h1_prior_level_retest5pct | 5 (2) | 0.530 | 22 (17) | -0.516 | 1 |
| gold_v180/JAN | h1_prior_retest_1r_target_conflict | 2 (1) | 0.062 | 25 (18) | -0.353 | 1 |
| gold_v180/JAN | h1_log_structure_against | 6 (4) | -0.089 | 21 (15) | -0.389 | 1 |
| gold_v180/JAN | h1_log_structure_range | 12 (8) | -0.279 | 15 (11) | -0.356 | 1 |
| gold_v180/JAN | h4_ema_against | 7 (6) | -0.533 | 7 (5) | -0.395 | 14 |
| gold_v180/JAN | h4_slope_against | 12 (9) | -0.352 | 9 (7) | -0.524 | 7 |
| gold_v180/JAN | prior_day_directional_outer_quartile | 7 (4) | -0.044 | 19 (15) | -0.501 | 2 |
| gold_v190/JAN | h1_ema_against | 12 (9) | -0.600 | 9 (8) | -0.675 | 2 |
| gold_v190/JAN | h1_slope_against | 10 (8) | -0.619 | 11 (9) | -0.644 | 2 |
| gold_v190/JAN | h1_momentum_against | 6 (5) | -0.514 | 16 (12) | -0.338 | 1 |
| gold_v190/JAN | h1_range_er12 | 10 (9) | -0.719 | 12 (8) | -0.109 | 1 |
| gold_v190/JAN | h1_previous_body_against | 7 (5) | 0.248 | 16 (13) | -0.702 | 0 |
| gold_v190/JAN | h1_large_rejection_wick | 7 (6) | -0.726 | 16 (12) | -0.276 | 0 |
| gold_v190/JAN | h1_vol_expansion | 0 (0) | NA | 21 (17) | -0.632 | 2 |
| gold_v190/JAN | h1_stretched_from_ema20 | 4 (3) | -0.754 | 17 (14) | -0.604 | 2 |
| gold_v190/JAN | h1_directional_outer_quartile24 | 4 (3) | -0.754 | 17 (14) | -0.604 | 2 |
| gold_v190/JAN | h1_directional_outer_quartile48 | 7 (5) | -0.576 | 14 (12) | -0.660 | 2 |
| gold_v190/JAN | h1_obstacle_inside1r | 7 (5) | -0.435 | 12 (10) | -0.684 | 4 |
| gold_v190/JAN | h1_prior_level_retest5pct | 5 (3) | -0.025 | 17 (14) | -0.492 | 1 |
| gold_v190/JAN | h1_prior_retest_1r_target_conflict | 2 (1) | -0.005 | 20 (16) | -0.424 | 1 |
| gold_v190/JAN | h1_log_structure_against | 5 (3) | -0.227 | 17 (14) | -0.433 | 1 |
| gold_v190/JAN | h1_log_structure_range | 10 (7) | -0.131 | 12 (10) | -0.598 | 1 |
| gold_v190/JAN | h4_ema_against | 5 (4) | -0.627 | 6 (4) | -0.345 | 12 |
| gold_v190/JAN | h4_slope_against | 10 (7) | -0.517 | 7 (6) | -0.578 | 6 |
| gold_v190/JAN | prior_day_directional_outer_quartile | 6 (4) | -0.338 | 15 (13) | -0.750 | 2 |
| usd_v180/JAN | h1_ema_against | 17 (10) | -0.197 | 14 (10) | -0.386 | 1 |
| usd_v180/JAN | h1_slope_against | 16 (8) | -0.047 | 15 (12) | -0.533 | 1 |
| usd_v180/JAN | h1_momentum_against | 12 (7) | -0.106 | 20 (14) | -0.426 | 0 |
| usd_v180/JAN | h1_range_er12 | 13 (11) | -0.847 | 19 (10) | 0.064 | 0 |
| usd_v180/JAN | h1_previous_body_against | 13 (9) | -0.468 | 19 (12) | -0.195 | 0 |
| usd_v180/JAN | h1_large_rejection_wick | 5 (4) | -0.602 | 27 (17) | -0.251 | 0 |
| usd_v180/JAN | h1_vol_expansion | 1 (1) | -1.013 | 30 (19) | -0.258 | 1 |
| usd_v180/JAN | h1_stretched_from_ema20 | 7 (6) | -0.707 | 25 (15) | -0.194 | 0 |
| usd_v180/JAN | h1_directional_outer_quartile24 | 8 (6) | -0.414 | 23 (14) | -0.236 | 1 |
| usd_v180/JAN | h1_directional_outer_quartile48 | 8 (6) | -0.427 | 23 (14) | -0.232 | 1 |
| usd_v180/JAN | h1_obstacle_inside1r | 14 (10) | -0.378 | 16 (9) | -0.156 | 2 |
| usd_v180/JAN | h1_prior_level_retest5pct | 10 (7) | -0.270 | 22 (14) | -0.323 | 0 |
| usd_v180/JAN | h1_prior_retest_1r_target_conflict | 3 (3) | -1.010 | 29 (18) | -0.233 | 0 |
| usd_v180/JAN | h1_log_structure_against | 13 (8) | -0.258 | 19 (13) | -0.339 | 0 |
| usd_v180/JAN | h1_log_structure_range | 11 (7) | -0.159 | 21 (14) | -0.383 | 0 |
| usd_v180/JAN | h4_ema_against | 9 (4) | 0.034 | 10 (8) | -0.600 | 13 |
| usd_v180/JAN | h4_slope_against | 14 (8) | -0.246 | 15 (11) | -0.391 | 3 |
| usd_v180/JAN | prior_day_directional_outer_quartile | 7 (6) | -0.707 | 24 (14) | -0.158 | 1 |
| usd_v180/POST_JAN | h1_ema_against | 25 (14) | 0.004 | 23 (13) | -0.122 | 0 |
| usd_v180/POST_JAN | h1_slope_against | 20 (9) | 0.108 | 28 (18) | -0.174 | 0 |
| usd_v180/POST_JAN | h1_momentum_against | 24 (14) | -0.165 | 24 (13) | 0.052 | 0 |
| usd_v180/POST_JAN | h1_range_er12 | 22 (13) | -0.209 | 26 (14) | 0.073 | 0 |
| usd_v180/POST_JAN | h1_previous_body_against | 12 (7) | -0.030 | 36 (20) | -0.065 | 0 |
| usd_v180/POST_JAN | h1_large_rejection_wick | 7 (3) | 0.480 | 41 (24) | -0.148 | 0 |
| usd_v180/POST_JAN | h1_vol_expansion | 0 (0) | NA | 48 (27) | -0.056 | 0 |
| usd_v180/POST_JAN | h1_stretched_from_ema20 | 14 (8) | 0.067 | 34 (19) | -0.107 | 0 |
| usd_v180/POST_JAN | h1_directional_outer_quartile24 | 16 (10) | -0.154 | 32 (17) | -0.008 | 0 |
| usd_v180/POST_JAN | h1_directional_outer_quartile48 | 12 (6) | 0.082 | 36 (21) | -0.103 | 0 |
| usd_v180/POST_JAN | h1_obstacle_inside1r | 28 (16) | -0.043 | 18 (10) | -0.086 | 2 |
| usd_v180/POST_JAN | h1_prior_level_retest5pct | 11 (6) | 0.168 | 37 (21) | -0.123 | 0 |
| usd_v180/POST_JAN | h1_prior_retest_1r_target_conflict | 5 (2) | 0.204 | 43 (25) | -0.087 | 0 |
| usd_v180/POST_JAN | h1_log_structure_against | 16 (8) | 0.039 | 32 (19) | -0.104 | 0 |
| usd_v180/POST_JAN | h1_log_structure_range | 14 (7) | 0.219 | 34 (20) | -0.170 | 0 |
| usd_v180/POST_JAN | h4_ema_against | 19 (9) | 0.093 | 29 (18) | -0.155 | 0 |
| usd_v180/POST_JAN | h4_slope_against | 25 (14) | 0.004 | 23 (13) | -0.122 | 0 |
| usd_v180/POST_JAN | prior_day_directional_outer_quartile | 15 (7) | 0.108 | 33 (20) | -0.131 | 0 |

## Definitions and causal limits

- All dates are source/broker clock. No UTC or market-session conversion is assumed.
- H1 aggregates require exactly 12 grid-aligned M5 bars; H4 exactly 48. All member known_at and full-bin close must be <= actual fill_at. Incomplete bins are discarded and explicitly exported. Completely absent holiday/weekend bins are not invented.
- Features use only eligible closed aggregate bars at each fill. H1/H4 EMA20/50 seed with period SMA and require full warmup. ATR14/50 are trailing SIMPLE mean true ranges (not Wilder smoothing). ER12 uses 13 closes /12 moves. Lookbacks count completed observed bars, so may span session gaps; last24 span is exported.
- H1/H4 current forming candle never enters entry features. No pre-start history was fetched, so early January EMA50, H4 and range48 fields are unavailable; missing is not silently RANGE or safe.
- Prior observed-day range uses the latest prior source date with >=144 M5 bars spanning >=12 hours. It is an observed range, not an asserted complete exchange session/day. Current-day completed bars do not enter that range.
- H1 pivots use PIVOT_CONFIRMED and max(event_at,observed_pivot_known_at)<=fill. Structural prior-level candidates additionally require source pivot time < W1 origin, preventing the current W1 high/low itself from masquerading as historical resistance/support. Same H1 move is represented once, not duplicated with M15/M5 levels.
- Retest5pct means absolute prior-level/W1peak difference <=5% of W1span. It is a prior high/low retest candidate, not a confirmed double top/bottom and not proof that a reversal was predictable. Known prior levels may already have been broken; no extra post-hoc survival filter is applied.
- h1_prior_beyond_peak is nearest directional prior H1 level beyond the W1 endpoint. h1_nearest_known_obstacle includes all known H1 pivots ahead of entry and can include the current move; both definitions stay separate.
- 1R-target-conflict is a diagnostic geometric test. v190 has no fixed TP, so this is hypothetical for that run. Price-distance R uses FILL entry and original SL, while realized R is the log's actual net-cash/initial-money-risk result.
- Exits are grouped once per setup. Run gold_v180 and gold_v190 use different exit policies and stop on different January dates; comparison is not a controlled strategy A/B. USD post-January is February-March 27 only, not a full-year holdout.
- No comparison modifies entries, cash, risk, sizing or subsequent candidates. A flag's mean R is a conditional description, not the balance/PF of a rerun that skips it.

## Fixed ER12 threshold: month and direction checks

| Run/month/side | ER<=.25 N / loss / sum R | ER>.25 N / loss / sum R |
|---|---:|---:|
| gold_v180/2025-01/ALL | 12 / 9 / -4.517 | 15 / 10 / -4.181 |
| gold_v180/2025-01/LONG | 4 / 3 / -1.812 | 7 / 3 / 1.492 |
| gold_v180/2025-01/SHORT | 8 / 6 / -2.705 | 8 / 7 / -5.674 |
| gold_v190/2025-01/ALL | 10 / 9 / -7.187 | 12 / 8 / -1.302 |
| gold_v190/2025-01/LONG | 3 / 3 / -2.024 | 6 / 3 / 3.723 |
| gold_v190/2025-01/SHORT | 7 / 6 / -5.163 | 6 / 5 / -5.025 |
| usd_v180/2025-01/ALL | 13 / 11 / -11.011 | 19 / 10 / 1.217 |
| usd_v180/2025-01/LONG | 7 / 5 / -4.742 | 9 / 3 / 4.569 |
| usd_v180/2025-01/SHORT | 6 / 6 / -6.269 | 10 / 7 / -3.352 |
| usd_v180/2025-02/ALL | 7 / 3 / 0.427 | 11 / 8 / -1.160 |
| usd_v180/2025-02/LONG | 5 / 2 / 0.647 | 4 / 3 / -1.695 |
| usd_v180/2025-02/SHORT | 2 / 1 / -0.220 | 7 / 5 / 0.535 |
| usd_v180/2025-03/ALL | 15 / 10 / -5.022 | 15 / 6 / 3.049 |
| usd_v180/2025-03/LONG | 7 / 5 / -2.958 | 8 / 1 / 6.778 |
| usd_v180/2025-03/SHORT | 8 / 5 / -2.064 | 7 / 5 / -3.729 |

February USD reverses the aggregate low-ER association. Gold v180 SHORT also does not support blanket low-ER exclusion. These counterexamples are retained, not tuned away.

## Threshold inventory

- `h1_ema_against`: EMA20<EMA50 for LONG; inverse SHORT; 50 closed H1 warmup
- `h1_slope_against`: entry-direction EMA20 change over 3 closed H1 bars <0
- `h1_momentum_against`: entry-direction H1 close change over 3 completed bars <0
- `h1_range_er12`: ER12<=0.25; abs net close change /sum 12 abs close changes
- `h1_previous_body_against`: latest CLOSED H1 body points opposite entry
- `h1_large_rejection_wick`: LONG upper wick/whole range>=0.5; SHORT lower wick inverse
- `h1_vol_expansion`: ATR14/ATR50>=1.5; both SMA true range
- `h1_stretched_from_ema20`: entry >=1 H1 ATR14 beyond EMA20 in trade direction
- `h1_directional_outer_quartile24`: LONG last24 completed H1 position>=.75; SHORT<=.25
- `h1_directional_outer_quartile48`: LONG last48 completed H1 position>=.75; SHORT<=.25
- `h1_obstacle_inside1r`: nearest past known H1 swing high/low ahead lies within original 1R
- `h1_prior_level_retest5pct`: H1 prior high/low source before W1 origin is within .05*W1span of W1peak
- `h1_prior_retest_1r_target_conflict`: prior retest flag AND prior directional level distance from entry is (0,1R); v190 hypothetical
- `h1_log_structure_against`: existing log H1 structure AGAINST, only >=2 known H1 highs AND lows
- `h1_log_structure_range`: existing log H1_RANGE, only >=2 known H1 highs AND lows
- `h4_ema_against`: H4 EMA20/50 opposite entry; 50 full H4 warmup
- `h4_slope_against`: entry-direction H4 EMA20 change over3 full bars <0
- `prior_day_directional_outer_quartile`: entry directional position >=.75 in prior observed trade-day range
