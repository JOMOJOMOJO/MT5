# Strategy_01B_J_SHORT g039 Production Ops Summary

This cycle did not change entry logic, C/J StrategyMode logic, TP/SL calculation, fixed 1.5R exit, lot sizing, or existing strategy filters. It added production-operation controls and deal-level evidence.

Compile: `reports/compile/ExpectedValue_NWave_Scalper_g039_production_ops.log` reported 0 errors / 0 warnings.

|Run|Trades|WinRate%|AvgWinR|AvgLossR|ExpectancyR|PF|MaxDD_R|MaxDD%|TotalR|MaxCL|RiskRejects|LiveErrors|DD%Stops|PeriodRStops|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|g039 raw live-path 2024.01.01-2026.04.30|303|40.9241|1.5139|-1.0320|0.0099|1.0162|23.6686|5.6557|2.9919|12|0|0|0|0|
|g039 production guard 2025.01.01-2025.12.31|92|48.9130|1.4965|-1.0385|0.2014|1.3797|11.5745|2.9744|18.5323|8|9|0|0|10|
|g039 production guard 2026.01.01-2026.04.30|38|47.3684|1.4885|-1.0112|0.1729|1.3249|5.0907|1.6717|6.5698|3|1|0|0|2|
|g039 production guard 2024.01.01-2026.04.30|277|42.2383|1.5177|-1.0334|0.0441|1.0739|24.2826|5.8883|12.2202|8|42|0|0|39|

Key distinction: DD% Soft/Hard/Emergency stops did not fire in 2025 or 2026 OOS. Daily/monthly R guards did fire as temporary protective pauses.

Conclusion: proceed to controlled `EnableTrading=true` demo for g039 only. Do not proceed to small live or full production yet.
