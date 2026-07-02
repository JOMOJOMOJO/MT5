# Transcript Nested Third-Wave Search

## Scope
- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Concept: H1 context, M15 confirmed swing break, M5 first-pullback/retest entry, 75SMA/Granville-style diagnostics.
- Search window: January 2025. Q1 c1 was attempted first but did not produce a fresh MT5 report within 15 minutes, so the five-cycle search was shortened to one month.
- Tester period remains M15; EA internally scans `InpPrimaryEntryTF=PERIOD_M5` closed bars.
- Note: c1-c5 Jan rows are retained as evidence of a preset bug. They used `InpTopContextTF=60`; MQL5 requires `PERIOD_H1=16385`, so those rows are not valid strategy evidence. Practical cycles after fixing this are c6-c10.

## Comparison
- `c1_jan_counter_m15break_sma`: trades=0 projected_year_trades=0 PF=0.00 avg_R=0.0000 net=0.00 MaxDD=0.00 fullSL=0.0%
- `c2_jan_counter_m15break_no_sma_gate`: trades=0 projected_year_trades=0 PF=0.00 avg_R=0.0000 net=0.00 MaxDD=0.00 fullSL=0.0%
- `c3_jan_notopposite_m15break_sma`: trades=0 projected_year_trades=0 PF=0.00 avg_R=0.0000 net=0.00 MaxDD=0.00 fullSL=0.0%
- `c4_jan_counter_sma_m5_failure_exit`: trades=0 projected_year_trades=0 PF=0.00 avg_R=0.0000 net=0.00 MaxDD=0.00 fullSL=0.0%
- `c5_jan_counter_sma_failure_exit_relaxed_retest`: trades=0 projected_year_trades=0 PF=0.00 avg_R=0.0000 net=0.00 MaxDD=0.00 fullSL=0.0%
- `c6_jan_counter_m15break_diagnostic_sma`: trades=28 projected_year_trades=336 PF=0.49 avg_R=-0.3021 net=-205.98 MaxDD=213.53 fullSL=53.6%
- `c7_jan_counter_m15break_diagnostic_no_sma_gate`: trades=38 projected_year_trades=456 PF=0.54 avg_R=-0.2707 net=-251.10 MaxDD=251.10 fullSL=52.6%
- `c8_jan_notopposite_m15break_diagnostic_sma`: trades=27 projected_year_trades=324 PF=0.47 avg_R=-0.3144 net=-204.91 MaxDD=204.91 fullSL=55.6%
- `c9_jan_counter_diag_sma_m5_failure_exit`: trades=28 projected_year_trades=336 PF=0.49 avg_R=-0.2210 net=-152.76 MaxDD=175.30 fullSL=25.0%
- `c10_jan_counter_diag_sma_failure_exit_relaxed_retest`: trades=31 projected_year_trades=372 PF=0.51 avg_R=-0.2026 net=-156.71 MaxDD=180.94 fullSL=22.6%

## Search Decision
- Best Jan row by avg_R/PF/trade count: `c10_jan_counter_diag_sma_failure_exit_relaxed_retest` with trades=31, PF=0.51, avg_R=-0.2026, net=-156.71.
- Jan search gate pass candidates: none.
- A January pass is not an operating pass; it only selects one candidate for 2025 fixed validation.

## Artifacts
- `comparison.csv`
- `trades_all_scenarios.csv`
- `symbol_breakdown.csv`
- `direction_breakdown.csv`
- `transcript_stage_breakdown.csv`
- `sma75_breakdown.csv`
- `failure_type_breakdown.csv`
- `r_metrics.csv`


## 2025 Fixed Validation: c10
- Full-year run: `c10_full2025_counter_diag_sma_failure_exit_relaxed_retest`.
- Trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, MaxDD=1179.96, fullSL=10.4%, TP=15.4%.
- Gate result: failed. PF < 1.05, avg_R < 0, net < 0. It does not advance to 3-year fixed BT or OOS.
- Artifacts: `full2025_comparison.csv`, `full2025_symbol_breakdown.csv`, `full2025_direction_breakdown.csv`, `full2025_failure_type_breakdown.csv`.
