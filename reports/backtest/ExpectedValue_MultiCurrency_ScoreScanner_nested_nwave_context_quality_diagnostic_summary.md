# Nested N-Wave Context Quality Diagnostic

## Scope

- This is a diagnostic comparison, not Router v2.
- Existing EA logic, Router labels, order handling, SL/TP, RewardR, timeframe, spread guard, and risk calculation were not changed.
- The comparison focuses on `dirty_breakout` and `weak_breakout` candidates from the prior Router decision audit.
- Main contrast: 2025-10 removed winners versus 2026-Q1 avoided losers.

## Cohort Summary

| cohort | candidates | PF | avg_R | net | avg context score | avg H4 fib | avg SL ATR | avg touch count | avg close strength | avg close dist ATR |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-02_other_dirty_weak | 38 | 1.04 | 0.026 | 47.28 | 3.97 | 50.84 | 1.718 | 8.05 | 0.467 | 0.453 |
| 2025-08_other_dirty_weak | 19 | 2.243 | 0.579 | 513.65 | 3.42 | 49.25 | 1.828 | 8.58 | 0.537 | 0.328 |
| 2025_10_removed_loser_dirty_weak | 12 | 0.0 | -1.0 | -568.18 | 4.17 | 44.7 | 1.813 | 6.0 | 0.438 | 0.245 |
| 2025_10_removed_winner_dirty_weak | 11 |  | 2.0 | 1031.96 | 3.27 | 53.02 | 1.523 | 10.0 | 0.542 | 0.323 |
| 2026_q1_avoided_loser_dirty_weak | 82 | 0.0 | -1.0 | -3772.96 | 4.04 | 50.15 | 1.705 | 8.26 | 0.537 | 0.388 |
| 2026_q1_removed_winner_dirty_weak | 29 |  | 2.0 | 2769.38 | 4.0 | 51.45 | 1.614 | 8.62 | 0.477 | 0.443 |

## Dirty / Weak Split

| cohort | decision | candidates | PF | avg_R | net | false return % | reached 2R % | avg context score |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 2025_10_removed_winner_dirty_weak | dirty_skipped | 7 |  | 2.0 | 638.4 | 42.86 | 100.0 | 2.86 |
| 2025_10_removed_winner_dirty_weak | weak_routed_to_retest | 4 |  | 2.0 | 393.56 | 50.0 | 100.0 | 4.0 |
| 2026_q1_avoided_loser_dirty_weak | dirty_skipped | 57 | 0.0 | -1.0 | -2624.98 | 68.42 | 0.0 | 3.68 |
| 2026_q1_avoided_loser_dirty_weak | weak_routed_to_retest | 25 | 0.0 | -1.0 | -1147.98 | 72.0 | 0.0 | 4.84 |

## Interpretation

- The crude `context_quality_v0` score did **not** separate the cohorts: 2025-10 removed winners scored `3.27` while 2026-Q1 avoided losers scored `4.04`. Do not promote this v0 score into a gate.
- 2025-10 removed winners had lower false-return rate (`45.45%`) than 2026-Q1 avoided losers (`69.51%`).
- 2026-Q1 avoided losers had higher average MAE (`1.241`R) than the 2025-10 removed winners (`0.434`R).
- Basic M15 candle strength was not enough: average close strength was `0.542` for 2025-10 removed winners and `0.537` for 2026-Q1 avoided losers.
- The strongest observed separators are partly post-entry path metrics (`false_return`, `MAE`, `MFE`). They are useful for diagnosis, but the next implementation needs pre-entry proxies for those paths.
- `dirty` winners in 2025-10 still reached 2R in `100.0%`; `dirty` losers in 2026-Q1 reached 2R in `0.0%`. This supports context-dependent routing rather than a hard dirty skip.
- `weak` winners in 2025-10 had avg_R `2.0` versus `weak` losers in 2026-Q1 avg_R `-1.0`. Weak breakout is not intrinsically bad; it needs context classification.

## Buckets More Common In 2025-10 Removed Winners

- `context_quality_v0`:
  - `poor_context_v0`: winners 72.73%, Q1 losers 54.88%, delta 17.85pt
  - `mixed_context_v0`: winners 18.18%, Q1 losers 25.61%, delta -7.43pt
  - `clean_context_v0`: winners 9.09%, Q1 losers 19.51%, delta -10.42pt
- `sl_atr_bucket`:
  - `1.0-1.5`: winners 45.45%, Q1 losers 25.61%, delta 19.84pt
  - `<1.0_tight`: winners 9.09%, Q1 losers 3.66%, delta 5.43pt
  - `2.0+_wide`: winners 27.27%, Q1 losers 26.83%, delta 0.44pt
- `neckline_touch_bucket`:
  - `5-8_moderate`: winners 45.45%, Q1 losers 31.71%, delta 13.75pt
  - `9-12_tested`: winners 36.36%, Q1 losers 31.71%, delta 4.66pt
  - `13+_stale`: winners 18.18%, Q1 losers 14.63%, delta 3.55pt
- `close_strength_bucket`:
  - `<0.35_weak_close`: winners 36.36%, Q1 losers 35.37%, delta 1.0pt
  - `0.60+_strong_close`: winners 45.45%, Q1 losers 45.12%, delta 0.33pt
  - `0.35-0.60_mixed_close`: winners 18.18%, Q1 losers 19.51%, delta -1.33pt
- `close_distance_bucket`:
  - `<0.20_shallow_break`: winners 63.64%, Q1 losers 45.12%, delta 18.51pt
  - `0.80+_far`: winners 9.09%, Q1 losers 10.98%, delta -1.88pt
  - `0.40-0.80_extended`: winners 18.18%, Q1 losers 21.95%, delta -3.77pt
- `body_atr_bucket`:
  - `<0.25_small_body`: winners 63.64%, Q1 losers 34.15%, delta 29.49pt
  - `0.60-1.00_large`: winners 18.18%, Q1 losers 15.85%, delta 2.33pt
  - `1.00+_overextended`: winners 0.0%, Q1 losers 10.98%, delta -10.98pt
- `mfe_bucket`:
  - `2R+`: winners 100.0%, Q1 losers 0.0%, delta 100.0pt
  - `1-1.5R`: winners 0.0%, Q1 losers 15.85%, delta -15.85pt
  - `1.5-2R`: winners 0.0%, Q1 losers 20.73%, delta -20.73pt

## Buckets More Common In 2026-Q1 Avoided Losers

- `context_quality_v0`:
  - `clean_context_v0`: winners 9.09%, Q1 losers 19.51%, delta -10.42pt
  - `mixed_context_v0`: winners 18.18%, Q1 losers 25.61%, delta -7.43pt
  - `poor_context_v0`: winners 72.73%, Q1 losers 54.88%, delta 17.85pt
- `sl_atr_bucket`:
  - `1.5-2.0`: winners 18.18%, Q1 losers 43.9%, delta -25.72pt
  - `2.0+_wide`: winners 27.27%, Q1 losers 26.83%, delta 0.44pt
  - `<1.0_tight`: winners 9.09%, Q1 losers 3.66%, delta 5.43pt
- `neckline_touch_bucket`:
  - `1-4_fresh`: winners 0.0%, Q1 losers 21.95%, delta -21.95pt
  - `13+_stale`: winners 18.18%, Q1 losers 14.63%, delta 3.55pt
  - `9-12_tested`: winners 36.36%, Q1 losers 31.71%, delta 4.66pt
- `close_strength_bucket`:
  - `0.35-0.60_mixed_close`: winners 18.18%, Q1 losers 19.51%, delta -1.33pt
  - `0.60+_strong_close`: winners 45.45%, Q1 losers 45.12%, delta 0.33pt
  - `<0.35_weak_close`: winners 36.36%, Q1 losers 35.37%, delta 1.0pt
- `close_distance_bucket`:
  - `0.20-0.40_normal`: winners 9.09%, Q1 losers 21.95%, delta -12.86pt
  - `0.40-0.80_extended`: winners 18.18%, Q1 losers 21.95%, delta -3.77pt
  - `0.80+_far`: winners 9.09%, Q1 losers 10.98%, delta -1.88pt
- `body_atr_bucket`:
  - `0.25-0.60_normal`: winners 18.18%, Q1 losers 39.02%, delta -20.84pt
  - `1.00+_overextended`: winners 0.0%, Q1 losers 10.98%, delta -10.98pt
  - `0.60-1.00_large`: winners 18.18%, Q1 losers 15.85%, delta 2.33pt
- `mae_bucket`:
  - `1-1.5R`: winners 0.0%, Q1 losers 81.71%, delta -81.71pt
  - `1.5-2R`: winners 0.0%, Q1 losers 15.85%, delta -15.85pt
  - `2R+`: winners 0.0%, Q1 losers 2.44%, delta -2.44pt

## Next Step

- Do not implement fixed gates yet.
- Add richer Context Quality diagnostics to the Router branch next. The existing audit columns are not enough: the crude v0 label misclassifies too many 2025-10 winners as poor context.
- Prioritize missing pre-entry context metrics: H4 obstacle room to 2R, H1 counter N-wave break quality, M15 pre-break extension, neckline age, and 1R-to-2R continuation room.
- Keep routing unchanged until those diagnostics prove they preserve 2025-10 winners while continuing to avoid 2026-Q1 false-break losers.

## Artifacts

- Candidate rows: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_candidate_rows.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_candidate_rows.csv)
- Comparison CSV: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_comparison.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_comparison.csv)
- Bucket matrix: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_bucket_matrix.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_bucket_matrix.csv)
- Cohort diff: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_cohort_diff.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_cohort_diff.csv)
- Next router notes: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_next_router_notes.md](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_next_router_notes.md)
