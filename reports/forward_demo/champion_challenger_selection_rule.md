# Champion / Challenger Selection Rule

Champion: `g039` remains active until a Challenger passes the same live-path standard.

- IS: previous 12 months. OOS: next or most recent 3 months.
- Use only `EnableTrading=true` live-path tester results and deal-level logs.
- Require OOS ExpectancyR > 0, PF > 1.05, at least 30 trades, AvgLossR near -1R, live errors = 0.
- Reject one-month-only winners.
- Require production guard test with no DD% Soft/Hard/Emergency stop in normal windows.
- If return improves but DD or execution error risk worsens materially, reject.
- Emergency re-optimization while live is prohibited: stop first, diagnose second, test third.
