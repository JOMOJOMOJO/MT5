# Strategy_01B Forward Demo Monitoring Regression

Generated: 2026-05-15. Scope: monitoring/preflight/daily-summary only; no entry, C/J strategy condition, TP/SL, or risk-guard decision logic was intentionally optimized.

## Compile
`reports/compile/ExpectedValue_NWave_Scalper.log`: `0 errors, 0 warnings`.

## Runs
|Run|EnableTrading|Risk|MaxOpenRisk|MaxSpread|Preflight|Warnings|Closed|Virtual entries|Live entries|Rejected|Unsafe blocked|ExpR|PF|MaxDD_R|Stop days|Live errors|
|---|---:|---:|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
|signal_only_safe_j_short_2026q1|false|0.25|0.25|30.0|PASS||30|30|0|860|0|0.3328|1.7132|4.0000|2|0|
|live_smoke_safe_j_short_2026q1|true|0.25|0.25|30.0|PASS||29|0|29|861|0|0.0955|1.1693|5.5422|2|0|
|unsafe_block_j_short_2026q1|true|1.00|1.00|50.0|BLOCK|risk_percent_above_0_25<br>max_total_open_risk_above_0_25<br>max_spread_points_above_30|0|0|0|890|50|0.0000|0.0000|0.0000|26|0|
|virtual_regression_j_short_vc_2026q1|false|0.25|0.25|50.0|WARN|max_spread_points_above_30|30|30|0|860|0|0.3328|1.7132|4.0000|2|0|

## Unsafe Setting Block Test
- Preflight status: `BLOCK`.
- Warnings: `risk_percent_above_0_25<br>max_total_open_risk_above_0_25<br>max_spread_points_above_30`.
- Closed trades: `0`.
- Live entries: `0`.
- `unsafe_forward_demo_setting_blocked`: `50`.
- Result: unsafe settings blocked new live entries as intended.

## Strategy Condition Regression
- J_SHORT virtual regression on 2026Q1: `30` closed trades, ExpectancyR `0.3328`, PF `1.7132`, MaxDD_R `4.0000`.
- This matches the prior J_SHORT very-conservative 2026Q1 readout, so the monitoring additions did not change the frozen Strategy_01B entry condition in signal-only validation.

## Samples
- `preflight_sample_safe_j_short.csv`
- `preflight_sample_unsafe_block.csv`
- `daily_summary_sample_safe_j_short.csv`
- `daily_summary_sample_unsafe_block.csv`
