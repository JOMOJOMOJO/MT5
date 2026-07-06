# Session Reversal Required-Light Adjacent Expansions

## Task

Test whether the prior `M15 wave2 required-light` fragment can be expanded one nearby condition at a time without reintroducing the losing baseline population.

This batch deliberately avoided broad expansion, symbol exclusion, direction-only repair, weekday filters, M5 ABC hard gates, and TP/BE/SL fine tuning.

## Implementation Notes

- Added `InpM15Wave2AdjacentMode` with modes for original required-light, wave1 age relaxation, wave2 age proxy relaxation, fib neighbor relaxation, adjacent break type, high-quality M5 near miss, context fib room near miss, best-two combination, and diagnostic-only.
- Added `InpM15Wave2AdjacentFibSide`, `InpM15Wave2AdjacentAgeExtraBars`, and `InpM15Wave2AdjacentCombineMask`.
- Exported adjacent diagnostics into signal/trade CSVs: required-light pass/reject reason, adjacent pass reason, relaxed component, fib side, and near-miss flag.
- Kept H1/M15/M5 as explicit MQL5 timeframe enum values in generated presets: H1=`16385`, M15=`15`, M5=`5`.
- Verified all exported trades used `selected_candidate_timeframe=PERIOD_M5`.
- Added Q1/full-year matrix generation and analysis scripts for this batch.
- Added analyzer-side deduplication because rerunning the same MT5 log folder appends trades in Common Files.

## Evidence

- Summary: `reports/backtest/runs/20260707_session_reversal_required_light_adjacent_expansions/summary.md`
- Full-year comparison: `reports/backtest/runs/20260707_session_reversal_required_light_adjacent_expansions/full2025_comparison.csv`
- Q1 comparison: `reports/backtest/runs/20260707_session_reversal_required_light_adjacent_expansions/q1_comparison.csv`
- All trades: `reports/backtest/runs/20260707_session_reversal_required_light_adjacent_expansions/trades_all_scenarios.csv`
- Compile log: `reports/backtest/runs/20260707_session_reversal_required_light_adjacent_expansions/compile.log`
- Matrix generator: `scripts/generate-session-reversal-required-light-adjacent-cycles.py`
- Analyzer: `scripts/analyze-session-reversal-required-light-adjacent-cycles.py`

## Result

Baseline c10 reproduced the prior failure: 318 trades, PF 0.59, avg_R -0.1582, avg_MFE 0.597R, time exit 74.2%.

Required-light reproduced the prior quality fragment: 50 trades, PF 1.34, avg_R +0.1099, avg_MFE 0.781R, MFE>=1R 40.0%, TP 30.0%, time exit 56.0%.

Adjacent expansion did not produce a promotion candidate:

- `relax_w1`: 55 trades, PF 1.16, avg_R +0.0549.
- `relax_w2`: 55 trades, PF 1.16, avg_R +0.0549.
- `fib_shallow`: 149 trades, PF 0.66, avg_R -0.1341.
- `fib_deep`: 50 trades, PF 1.34, avg_R +0.1099, effectively the original required-light population.
- `highq`: 243 trades, PF 0.70, avg_R -0.1123.
- `context`: 143 trades, PF 0.90, avg_R -0.0345.
- `combine`: 147 trades, PF 0.65, avg_R -0.1393.

The diagnostic near-miss run found 71 of 302 required-light rejects reached MFE>=1R, but the tested adjacent rules could not isolate those trades without pulling in enough losers to break PF and avg_R.

## Decision

No candidate passed the 2025 shallow gate. Do not run 3-year fixed BT or OOS for this batch.

The useful fragment remains real but too small: the all-symbol required-light row is positive, yet only 50 trades. The current adjacent expansions either do not add trades or mostly recover the baseline's losing distribution.

MT5 HTML reports were generated for all full-year rows except `full2025_base`; that row has EA CSV evidence and was rerun, but MT5 still did not produce a fresh HTML report.
