# ExpectedValue_NWave_Scalper Artifact Integrity Summary

Generated: 2026-05-15.

## Scope
- Purpose: verify the forward-demo monitoring artifacts are actually present in `mql/Experts/ExpectedValue_NWave_Scalper.mq5`.
- No strategy improvement was made in this integrity pass.
- Entry conditions, C/J StrategyMode conditions, TP/SL calculation, and existing risk guard decision logic were not changed in this pass.

## Implementation Presence
Monitoring implementation is present in `ExpectedValue_NWave_Scalper.mq5`.

## Grep Results
### `InpBlockUnsafeForwardDemoSettings`
```text
126:input bool            InpBlockUnsafeForwardDemoSettings = true;
2448:   if(!InpBlockUnsafeForwardDemoSettings)
```
### `unsafe_forward_demo_setting_blocked`
```text
2358:      SetStopCondition("unsafe_forward_demo_setting_blocked");
2463:   rejectReason = "unsafe_forward_demo_setting_blocked";
2484:      SetStopCondition("unsafe_forward_demo_setting_blocked");
3719:      SetStopCondition("unsafe_forward_demo_setting_blocked");
```
### `WriteForwardDemoPreflightCSV|preflight_`
```text
2467:void WriteForwardDemoPreflightCSV()
2471:   forwardDemoPreflightFileName = "preflight_" + TimestampForFile(now) + "_" + IntegerToString((int)MagicNumber) + ".csv";
2527:   CSVAppend(header, "preflight_status");
2528:   CSVAppend(header, "preflight_warnings");
4087:   WriteForwardDemoPreflightCSV();
```
### `WriteDailySummaryCSV|daily_summary_`
```text
2023:         WriteDailySummaryCSV("daily_rollover");
2568:void WriteDailySummaryCSV(string trigger)
2573:   string fileName = "daily_summary_" + DailyKeyToString(dailyKey) + "_" + IntegerToString((int)MagicNumber) + ".csv";
4113:   WriteDailySummaryCSV("OnDeinit");
```
### `stop_condition_triggered`
```text
2627:   CSVAppend(header, "stop_condition_triggered");
```
### `stop_reason`
```text
2628:   CSVAppend(header, "stop_reason");
```
### `csv_log_output_failed`
```text
2495:      SetStopCondition("csv_log_output_failed");
2580:      SetStopCondition("csv_log_output_failed");
2674:      SetStopCondition("csv_log_output_failed");
2723:      SetStopCondition("csv_log_output_failed");
```
### `missing_sl_tp_order`
```text
3701:         SetStopCondition("missing_sl_tp_order");
```

## Forward Demo Preset Check
`reports/presets/ExpectedValue_NWave_J_SHORT_demo_conservative.set` matches the forward-demo premise:
- `EnableTrading=false`
- `SelectedStrategyMode=2` (`STRATEGY_01B_J_SHORT`)
- `RiskPercent=0.25`
- `MaxTotalOpenRiskPercent=0.25`
- `MaxSpreadPoints=30.0`
- `AllowOnlyOnePositionForStrategy01B=true`
- `UseEquityCurveGuard=true`
- `InpBlockUnsafeForwardDemoSettings=true`

Note: the EA source defaults remain intentionally safer for generic attachment (`EnableTrading=false`, `SelectedStrategyMode=STRATEGY_01_ORIGINAL`). The forward-demo behavior is controlled by the demo preset.

## Compile Result
```text
 : information: generating code 90%
 : information: generating code 93%
 : information: generating code 95%
 : information: generating code 100%
 : information: code generated
Result: 0 errors, 0 warnings, 2347 ms elapsed, cpu='X64 Regular'
```

## Re-run Test Results
|Run|Preflight|Warnings|Closed|Virtual entries|Live entries|Rejected|Unsafe blocked|ExpectancyR|PF|MaxDD_R|Live errors|
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|safe_signal_only_j_short_2026q1|PASS||30|30|0|860|0|0.3328|1.7132|4.0000|0|
|safe_live_smoke_j_short_2026q1|PASS||29|0|29|861|0|0.0955|1.1693|5.5422|0|
|unsafe_setting_block_j_short_2026q1|BLOCK|risk_percent_above_0_25<br>max_total_open_risk_above_0_25<br>max_spread_points_above_30|0|0|0|890|50|0.0000|0.0000|0.0000|0|
|j_short_virtual_regression_2026q1|WARN|max_spread_points_above_30|30|30|0|860|0|0.3328|1.7132|4.0000|0|

## Safe Signal-only Result
- `safe_signal_only_j_short_2026q1`: 30 virtual closed trades, ExpectancyR `0.3328`, PF `1.7132`, MaxDD_R `4.0000`.

## Safe EnableTrading=true Smoke Result
- `safe_live_smoke_j_short_2026q1`: 29 live-path entries, 29 closed tester trades, live error count `0`.

## Unsafe Block Result
- `unsafe_setting_block_j_short_2026q1`: preflight `BLOCK`, live entries `0`, closed trades `0`, `unsafe_forward_demo_setting_blocked=50`.

## Strategy Condition Integrity
- J_SHORT virtual regression: 30 trades, ExpectancyR `0.3328`, PF `1.7132`, MaxDD_R `4.0000`.
- This matches the previous monitoring regression shape for J_SHORT 2026Q1, confirming no strategy-condition drift from the integrity check.

## Decision
- `J_SHORT` conservative preset can proceed to forward demo after manual signal-only review.
- This is not approval for live production.
- Live/main account operation remains blocked until forward-demo evidence satisfies the promotion checklist.
