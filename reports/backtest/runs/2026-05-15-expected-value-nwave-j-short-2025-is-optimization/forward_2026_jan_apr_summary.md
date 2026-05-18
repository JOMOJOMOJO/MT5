# Strategy_01B_J_SHORT 2026 Jan-Apr Out-of-Sample Forward Test Summary

Generated: 2026-05-15

## Scope
- Symbol/timeframe: USDJPY / M5
- Strategy: `STRATEGY_01B_J_SHORT`
- Out-of-sample window: `2026.01.01` - `2026.04.30`
- Parameter set fixed from 2025 IS before this run:
  - `DoubleTopBottomToleranceATR=0.25`
  - `NecklineBreakBufferATR=0.07`
  - `ADXLowThreshold=20.0`
  - `ADXHighThreshold=30.0`
- Exit: fixed internal `1.5R`
- Conservative same-bar exit: `true`

## OOS Results
|Run|EnableTrading|Trades|WinRate|AvgWinR|AvgLossR|ExpR|PF|MaxDD_R|MaxLossR|TotalR|RiskGuardRejects|LiveErrors|
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|virtual OOS|false|41|43.9024|1.499440|-1.000000|0.097315|1.173475|8.004638|-1.000000|3.989926|4|0|
|EnableTrading=true smoke|true|40|37.5000|1.472009|-1.019123|-0.084949|0.866633|11.726668|-1.105642|-3.397948|4|0|

## Virtual OOS Pass Check
- ExpectancyR > 0: pass (`0.097315`)
- PF > 1.1: pass (`1.173475`)
- Trades >= 30: pass (`41`)
- AvgLossR near -1R: pass (`-1.000000`)
- MaxDD_R: `8.004638`
- live_* errors: `0`

Virtual monthly ProfitR:
`2026-01:2.492 | 2026-02:3.997 | 2026-03:-0.005 | 2026-04:-2.494`

Virtual reject reason counts:
`break_candle_strength_filter_failed=32 | daily_loss_r_blocked=4 | direction_filter_failed=595 | entry_open_count_filter_failed=24 | fibo_filter_failed=9 | pattern_adx_bucket_filter_failed=179 | spread_too_wide=8 | trend_alignment_filter_failed=298`

## EnableTrading=true Smoke Note
The `EnableTrading=true` run is an execution-path smoke, not the primary virtual expectancy comparison. It recorded no live order/tracking/SLTP/lot errors, but tester fill/friction changed R materially:
- live-smoke ExpectancyR: `-0.084949`
- live-smoke PF: `0.866633`
- live-smoke MaxDD_R: `11.726668`

This is not a live promotion blocker by itself, but it is a strong reason to keep the next step at demo-forward only and monitor realized R carefully.

Evidence CSV: `oos_2026_jan_apr_selected_metrics.csv`
