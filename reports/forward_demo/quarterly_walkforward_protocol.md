# Quarterly Walkforward Protocol

Current Champion: `g039` / `STRATEGY_01B_J_SHORT`.

1. Review on a fixed quarterly cadence. Do not re-optimize during a drawdown unless the EA is stopped and root-cause analysis is complete.
2. Use the past 12 months as IS and the most recent 3 months as OOS.
3. Promotion metrics must use `EnableTrading=true` live-path tester/deal-level logs only. Virtual diagnostics are not promotion evidence.
4. Keep the Champion unless a Challenger clearly beats it and passes OOS.
5. If OOS fails, Champion continues or trading remains paused.
6. Preserve parameter sets, ranges, rejected sets, and deal logs under `reports/`.

Challenger minimums: OOS ExpectancyR > 0, PF > 1.05, trades >= 30, AvgLossR near -1R, live_* errors = 0, MaxDD_R / MaxDD% no worse than Champion or explicitly acceptable, and production guard test has no DD% Soft/Hard/Emergency stop in normal windows.
