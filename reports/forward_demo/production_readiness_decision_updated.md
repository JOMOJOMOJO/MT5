# Production Readiness Decision Updated

## Decision

- Controlled demo: yes, g039 can proceed to controlled demo.
- `EnableTrading=true` demo: yes, after preflight confirms USDJPY M5, J_SHORT/g039 parameters, RiskPercent <= 0.25, MaxTotalOpenRiskPercent <= 0.25, DD% guards ON, and logs are being written.
- Small live: no. Require 2-4 weeks and 30-50 demo live-path trades first.
- Full production: no. Evidence is not sufficient.

## Evidence

|Run|Trades|WinRate%|AvgWinR|AvgLossR|ExpectancyR|PF|MaxDD_R|MaxDD%|TotalR|MaxCL|RiskRejects|LiveErrors|DD%Stops|PeriodRStops|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|g039 raw live-path 2024.01.01-2026.04.30|303|40.9241|1.5139|-1.0320|0.0099|1.0162|23.6686|5.6557|2.9919|12|0|0|0|0|
|g039 production guard 2025.01.01-2025.12.31|92|48.9130|1.4965|-1.0385|0.2014|1.3797|11.5745|2.9744|18.5323|8|9|0|0|10|
|g039 production guard 2026.01.01-2026.04.30|38|47.3684|1.4885|-1.0112|0.1729|1.3249|5.0907|1.6717|6.5698|3|1|0|0|2|
|g039 production guard 2024.01.01-2026.04.30|277|42.2383|1.5177|-1.0334|0.0441|1.0739|24.2826|5.8883|12.2202|8|42|0|0|39|

2025 production guard: DD% Soft/Hard/Emergency stops = 0, Daily/Weekly/Monthly R stop events = 10. 2026 Jan-Apr OOS: DD% stops = 0, period R stop events = 2. The strict no-interruption production criterion is not fully satisfied if daily/monthly pauses are counted as stops; however, these are intended protective pauses, live errors are zero, and no DD% Soft/Hard/Emergency stop fired.

## RiskPercent and DD Control

Raw full-window MaxDD_R was 23.6686R. To mathematically keep a 15% DD budget, RiskPercent must be <= 0.6338%. To target a 10% DD budget, RiskPercent must be <= 0.4225%. These are upper bounds, not recommended starting risks.

Recommended operational risk:

- Demo: 0.10%-0.25%.
- Small live: 0.05%-0.10%.
- Production: only after demo/small-live review, maximum 0.25% unless future evidence supports otherwise.

`StopTradingAfterMaxDD_R=15` should not be the main production stop. Use DD% Soft/Hard/Emergency stops as the primary account-survival guard and keep the R stop as secondary diagnostic/legacy protection.

## DD% Guard Policy

Adopt DD% guards: SoftPause 8% with 5-day cooldown, HardStop 12% manual reset, EmergencyStop 15% manual reset and production stop.

## Next Quarterly Rule

Use Champion/Challenger. Current Champion is g039. Review quarterly using past 12 months IS and most recent 3 months OOS. Promotion decisions must use `EnableTrading=true` live-path results only; virtual results are diagnostic only.

## Remaining Tasks

- Run controlled demo on the intended broker/server for 2-4 weeks.
- Collect 30-50 demo live-path trades with deal-level logs.
- Verify live errors remain zero.
- Confirm AvgLossR stays near -1R under real demo execution.
- Verify SoftPause/HardStop/EmergencyStop behavior in a controlled test or documented dry run.
- Review slippage, spread, commission, and swap from deal-level logs before small live.
