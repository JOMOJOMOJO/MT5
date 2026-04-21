# USDJPY Intraday Feature / Regime Research Review

Date: 2026-04-21
Verdict: `hard-close unless a repeatable feature bundle survives`

## Scope

- primary families:
  - `Tokyo-London Session Box`
  - `Local Liquidity Sweep / Failed Acceptance`
  - `External Liquidity Sweep / Failed Acceptance`
  - `N-Wave Third-Leg`
- data windows:
  - `train 2025-04-01 -> 2025-12-31`
  - `oos 2026-01-01 -> 2026-04-01`
  - `actual 2024-11-26 -> 2026-04-01`

## Family Aggregate Read

- `External Liquidity Sweep`: OOS `14 trades / PF 1.38 / net 28.21`, actual `279 / PF 0.29 / net -3033.04`
- `Local Liquidity Sweep`: OOS `93 trades / PF 0.58 / net -422.43`, actual `1117 / PF 0.40 / net -7322.93`
- `N-Wave Third-Leg`: OOS `17 trades / PF 0.19 / net -112.65`, actual `485 / PF 0.35 / net -2579.49`
- `Tokyo-London Session Box`: OOS `55 trades / PF 0.95 / net -7.18`, actual `304 / PF 0.65 / net -390.75`

## Slightly Better Univariate Features

- `session_box | entry_session_bucket=tokyo_to_london`: OOS `12 / PF 4.54 / net 32.40`, actual `76 / PF 1.31 / net 61.23`, acceptance `46.05%`, time-stop `26.32%`, runner `5.26%`.
- `session_box | london_timing_bucket=30_60m`: OOS `14 / PF 0.22 / net -34.74`, actual `38 / PF 2.41 / net 97.35`, acceptance `36.84%`, time-stop `21.05%`, runner `10.53%`.
- `session_box | weekday=Thu`: OOS `15 / PF 0.24 / net -45.31`, actual `79 / PF 1.86 / net 174.10`, acceptance `40.51%`, time-stop `22.78%`, runner `12.66%`.
- `session_box | size_bucket=narrow`: OOS `19 / PF 1.55 / net 21.56`, actual `85 / PF 0.95 / net -14.96`, acceptance `48.24%`, time-stop `16.47%`, runner `9.41%`.
- `session_box | prev_day_alignment_type=far_prev_day_high`: OOS `25 / PF 2.90 / net 53.43`, actual `155 / PF 0.78 / net -126.21`, acceptance `63.87%`, time-stop `14.19%`, runner `8.39%`.
- `session_box | breakout_side=high_breakout`: OOS `31 / PF 1.95 / net 41.17`, actual `180 / PF 0.76 / net -155.83`, acceptance `64.44%`, time-stop `13.89%`, runner `8.33%`.
- `session_box | subtype=session_high_breakout`: OOS `31 / PF 1.95 / net 41.17`, actual `180 / PF 0.76 / net -155.83`, acceptance `64.44%`, time-stop `13.89%`, runner `8.33%`.
- `session_box | weekday=Tue`: OOS `7 / PF 5.12 / net 29.73`, actual `59 / PF 0.75 / net -47.56`, acceptance `64.41%`, time-stop `13.56%`, runner `3.39%`.
- `session_box | entry_strength_bucket=medium`: OOS `12 / PF 0.97 / net -0.94`, actual `118 / PF 0.74 / net -122.05`, acceptance `68.64%`, time-stop `14.41%`, runner `6.78%`.
- `session_box | entry_strength_bucket=strong`: OOS `41 / PF 1.12 / net 10.58`, actual `122 / PF 0.72 / net -102.73`, acceptance `47.54%`, time-stop `18.85%`, runner `4.10%`.

## Slightly Better Bivariate Bundles

- `session_box | london_timing_bucket x breakout_side=0_30m | low_breakout`: OOS `6 / PF 1.59 / net 9.94`, actual `28 / PF 1.41 / net 30.48`, acceptance `42.86%`, time-stop `42.86%`, runner `0.00%`.
- `session_box | entry_session_bucket x london_timing_bucket=tokyo_to_london | 30_60m`: OOS `5 / PF 0.28 / net -6.62`, actual `24 / PF 6.60 / net 129.11`, acceptance `20.83%`, time-stop `29.17%`, runner `16.67%`.
- `session_box | london_timing_bucket x breakout_side=30_60m | high_breakout`: OOS `10 / PF 0.63 / net -5.62`, actual `22 / PF 4.45 / net 98.42`, acceptance `31.82%`, time-stop `31.82%`, runner `18.18%`.
- `session_box | trigger_type x entry_strength_bucket=range_close_confirm | medium`: OOS `8 / PF 3.50 / net 22.89`, actual `62 / PF 0.90 / net -24.58`, acceptance `66.13%`, time-stop `12.90%`, runner `9.68%`.
- `session_box | breakout_side x trigger_type=high_breakout | range_retest_confirm`: OOS `10 / PF 3.76 / net 21.05`, actual `82 / PF 0.80 / net -61.58`, acceptance `67.07%`, time-stop `14.63%`, runner `7.32%`.
- `session_box | trigger_type x entry_strength_bucket=range_close_confirm | strong`: OOS `26 / PF 1.35 / net 17.87`, actual `70 / PF 0.79 / net -39.95`, acceptance `35.71%`, time-stop `25.71%`, runner `2.86%`.
- `session_box | prev_day_alignment_type x breakout_side=far_prev_day_high | high_breakout`: OOS `25 / PF 2.90 / net 53.43`, actual `155 / PF 0.78 / net -126.21`, acceptance `63.87%`, time-stop `14.19%`, runner `8.39%`.
- `session_box | breakout_side x trigger_type=low_breakout | range_close_confirm`: OOS `15 / PF 1.09 / net 3.82`, actual `66 / PF 0.73 / net -59.31`, acceptance `50.00%`, time-stop `24.24%`, runner `0.00%`.
- `session_box | breakout_side x trigger_type=high_breakout | range_close_confirm`: OOS `21 / PF 1.56 / net 20.12`, actual `98 / PF 0.72 / net -94.25`, acceptance `62.24%`, time-stop `13.27%`, runner `9.18%`.
- `session_box | london_timing_bucket x breakout_side=60m_plus | high_breakout`: OOS `15 / PF 1.71 / net 19.85`, actual `119 / PF 0.72 / net -129.23`, acceptance `67.23%`, time-stop `12.61%`, runner `8.40%`.

## Repeatability

- no bivariate feature bundle passed `PF >= 1 in OOS and actual`, minimum trade thresholds, and non-rescue dependence together.

## Weak Positive Hints

- `session_box | entry_session_bucket=tokyo_to_london`: OOS `12 / PF 4.54 / net 32.40`, actual `76 / PF 1.31 / net 61.23`, acceptance `46.05%`, time-stop `26.32%`, runner `5.26%`.

## Acceptance-Dominant Regimes

- `session_box | trigger_type x entry_strength_bucket=range_close_confirm | weak`: actual acceptance `87.50%` on `32` trades, PF `0.32`.
- `n_wave | subtype=lower_high_wave2`: actual acceptance `82.76%` on `58` trades, PF `0.17`.
- `n_wave | subtype x invalidation_line_type=lower_high_wave2 | wave1_low`: actual acceptance `82.76%` on `58` trades, PF `0.17`.
- `session_box | size_bucket=wide`: actual acceptance `81.54%` on `65` trades, PF `0.32`.
- `n_wave | trigger_type x entry_strength_bucket=recent_swing_breakdown | medium`: actual acceptance `81.18%` on `85` trades, PF `0.21`.
- `external_sweep | trigger_type x entry_strength_bucket=retest_failure | medium`: actual acceptance `80.00%` on `20` trades, PF `0.42`.
- `session_box | entry_strength_bucket=weak`: actual acceptance `79.69%` on `64` trades, PF `0.39`.
- `n_wave | entry_session_bucket=london_mid`: actual acceptance `79.17%` on `72` trades, PF `0.45`.

## Time-Stop-Reliant Regimes

- `local_sweep | entry_session_bucket=tokyo_to_london`: actual time-stop `64.71%`, time-stop-after-partial `5.88%`, runner `2.94%`.
- `local_sweep | size_bucket=wide`: actual time-stop `60.46%`, time-stop-after-partial `1.52%`, runner `1.14%`.
- `local_sweep | trigger_type x entry_strength_bucket=recent_swing_breakdown | strong`: actual time-stop `52.29%`, time-stop-after-partial `3.92%`, runner `4.58%`.
- `local_sweep | entry_session_bucket=ny_late`: actual time-stop `51.78%`, time-stop-after-partial `4.21%`, runner `8.09%`.
- `local_sweep | entry_session_bucket x london_timing_bucket=ny_late | 60m_plus`: actual time-stop `51.78%`, time-stop-after-partial `4.21%`, runner `8.09%`.
- `local_sweep | trigger_type x entry_strength_bucket=recent_swing_breakdown | medium`: actual time-stop `51.15%`, time-stop-after-partial `3.82%`, runner `6.87%`.
- `local_sweep | entry_session_bucket=london_mid`: actual time-stop `50.76%`, time-stop-after-partial `6.82%`, runner `6.06%`.
- `local_sweep | entry_session_bucket x london_timing_bucket=london_mid | 60m_plus`: actual time-stop `50.76%`, time-stop-after-partial `6.82%`, runner `6.06%`.

## Runner-Friendly Regimes

- `external_sweep | size_bucket=narrow`: actual runner `23.68%`, time-stop `23.68%`, PF `0.54`.
- `external_sweep | weekday=Fri`: actual runner `19.44%`, time-stop `27.78%`, PF `0.15`.
- `external_sweep | weekday=Mon`: actual runner `19.15%`, time-stop `6.38%`, PF `0.24`.
- `external_sweep | trigger_type x entry_strength_bucket=reclaim_close_confirm | strong`: actual runner `18.52%`, time-stop `40.74%`, PF `0.79`.
- `external_sweep | entry_strength_bucket=strong`: actual runner `18.31%`, time-stop `33.80%`, PF `0.70`.
- `session_box | london_timing_bucket x breakout_side=30_60m | high_breakout`: actual runner `18.18%`, time-stop `31.82%`, PF `4.45`.
- `session_box | entry_session_bucket x london_timing_bucket=tokyo_to_london | 30_60m`: actual runner `16.67%`, time-stop `29.17%`, PF `6.60`.
- `external_sweep | entry_session_bucket=tokyo`: actual runner `16.67%`, time-stop `36.11%`, PF `0.63`.

## Decision

- `Hard-close` if the goal is a standalone USDJPY intraday family.
- reason:
  - no bivariate feature bundle repeated in OOS and actual with enough trades
  - the only non-sparse repeat was a session-box univariate timing hint, not a reusable bundle
  - positive-looking slices were still sparse, acceptance-heavy, or time-stop driven
  - runner participation stayed weak, so the edge did not look like durable continuation
