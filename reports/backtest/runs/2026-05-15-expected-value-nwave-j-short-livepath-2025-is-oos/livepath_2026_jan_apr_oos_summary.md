# Strategy_01B_J_SHORT Live Path 2026 Jan-Apr OOS Summary

Generated: 2026-05-15

## Scope
- Out-of-sample window: `2026.01.01` - `2026.04.30`
- Evaluation path: `EnableTrading=true` tester order path
- The OOS window was not used to build the 2025 grid.
- The top 5 2025 IS candidates were fixed and run on OOS.

## OOS Results For 2025 IS Top 5
|IS Rank|Run|Trades|WinRate|AvgWinR|AvgLossR|ExpR|PF|MaxDD_R|TotalR|Positive Months|Live Errors|
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|4|g039 `tol0.20 neck0.07 adx22/32`|38|47.3684|1.488500|-1.011159|0.172890|1.324866|5.090685|6.569823|3|0|
|5|g030 `tol0.20 neck0.07 adx20/32`|46|39.1304|1.487736|-1.015651|-0.036065|0.941664|8.628610|-1.658974|2|0|
|1|g024 `tol0.25 neck0.07 adx20/30`|40|37.5000|1.472009|-1.019123|-0.084949|0.866633|11.726668|-3.397948|1|0|
|2|g003 `tol0.20 neck0.07 adx18/28`|47|31.9149|1.492992|-1.017797|-0.216482|0.687602|12.613343|-10.174638|1|0|
|3|g021 `tol0.20 neck0.07 adx20/30`|38|31.5789|1.475026|-1.018716|-0.231219|0.668274|11.726276|-8.786314|1|0|

## OOS Pass/Fail
Only `g039` passed the live-path OOS gate:
- ExpectancyR > 0: pass (`0.172890`)
- PF > 1.05: pass (`1.324866`)
- Trades >= 30: pass (`38`)
- AvgLossR near -1R: pass (`-1.011159`)
- live_* errors: pass (`0`)
- MaxDD_R: acceptable in this OOS window (`5.090685R`)

Monthly ProfitR for `g039`:
`2026-01:+0.992R | 2026-02:+5.366R | 2026-03:+2.278R | 2026-04:-2.066R`

Reject counts for `g039`:
`break_candle_strength_filter_failed=27 | daily_loss_r_blocked=1 | direction_filter_failed=560 | entry_open_count_filter_failed=22 | fibo_filter_failed=7 | pattern_adx_bucket_filter_failed=183 | spread_too_wide=8 | trend_alignment_filter_failed=264`

## Interpretation
The 2025 IS rank-1 candidate `g024` failed live-path OOS. That confirms the earlier warning: virtual-positive evidence is not enough, and even strong live-path IS rank is not sufficient for production.

`g039` is the only preselected top-5 candidate with positive live-path OOS. It is a demo candidate, not a production candidate.

Evidence:
- `livepath_2026_jan_apr_oos_metrics.csv`
- `raw/selected_g039_2026053404_diagnostics.csv`
