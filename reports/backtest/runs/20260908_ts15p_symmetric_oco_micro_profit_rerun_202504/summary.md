# Step 15P Deterministic Rerun

This is the independent formal rerun of the frozen April 2025 symmetric OCO
research configuration. It uses a distinct RunId and output directory and does
not append to the primary run.

- Period: 2025-04-01 through 2025-05-01 (development, not OOS)
- Model/driver: real ticks, EURUSD M1
- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- Actual orders/trades: zero
- Scenario rows: 428,436
- Comparison: PASS
- Normalized scenario SHA-256: `5BE622B6EC321366C98E8742275D0D4F09F25093911152497D47A473319ED4DD`

Only RunId-bearing identifier text was normalized. Detector population,
event identity, trigger direction/status, entry/exit prices and clocks,
TP/SL/TIME result, R, policy/provenance fields, and scenario geometry were
otherwise compared field-for-field.

See `reports/analysis/tick_shock/step15p/deterministic_rerun_comparison.csv`.
