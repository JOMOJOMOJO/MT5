# Session Reversal M15 Wave2 Expansion MFE Lift

## Task

Extended `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` to test whether the prior `M15 wave2 required-light` quality lift could be preserved while recovering trade count.

The change added separate M15 wave2 expansion and gate modes, kept M5 ABC/123 out of the main hard gate, and logged the interaction between M15 context, M5 pattern quality, MFE thresholds, and exit type.

## Implementation Notes

- Added `InpM15Wave2ExpansionMode` with staged modes for current required-light, pullback-only, wave1-or-wave2 context, not-opposite-plus-pullback, fib-or-structure pullback, and diagnostic-only.
- Added `InpM15Wave2GateMode` to separate no-gate, required-light, required-expanded, low-quality-only, score-only, diagnostic-only, and medium/low-quality gate behavior.
- Added CSV diagnostics for `m15_wave2_type`, `m15_wave2_score`, `m15_wave2_gate_pass`, `m15_wave2_gate_reject_reason`, `m5_pattern_quality_group`, and whether M15 wave2 was required due to M5 pattern quality.
- Generated a fixed run matrix using MQL5 timeframe enum values: H1=`16385`, M15=`15`, M5=`5`.
- Verified exported trades show `selected_candidate_timeframe=PERIOD_M5`.

## Evidence

- Summary: `reports/backtest/runs/20260703_session_reversal_m15_wave2_expansion_mfe_lift/summary.md`
- Full-year comparison: `reports/backtest/runs/20260703_session_reversal_m15_wave2_expansion_mfe_lift/full2025_comparison.csv`
- All trades: `reports/backtest/runs/20260703_session_reversal_m15_wave2_expansion_mfe_lift/trades_all_scenarios.csv`
- Compile log: `reports/backtest/runs/20260703_session_reversal_m15_wave2_expansion_mfe_lift/compile.log`
- Matrix generator: `scripts/generate-session-reversal-m15-wave2-expansion-cycles.py`
- Analyzer: `scripts/analyze-session-reversal-m15-wave2-expansion-cycles.py`

## Result

The previous required-light fragment was reproduced: 50 trades, PF 1.34, avg_R +0.1099, avg_MFE 0.781R, MFE>=1R 40.0%.

The broad M15 wave2 candidates recovered trade count but lost the edge:

- `m15_wave2_required_expanded`: 280 trades, PF 0.63, avg_R -0.1446.
- `m15_not_opposite_plus_pullback`: 229 trades, PF 0.66, avg_R -0.1293.
- `m15_wave1_or_wave2_context`: 314 trades, PF 0.58, avg_R -0.1637.

One-symbol expanded was mildly positive at 83 trades, PF 1.02, avg_R +0.0094, but it is below the 200-trade promotion threshold and remains a research fragment.

## Decision

No candidate passed the 2025 shallow gate. Do not run 3-year fixed BT or OOS for this batch.

The reusable lesson is that M15 wave2 context does separate better launches, but broadening it with loose pullback or not-opposite logic mostly reintroduces the baseline's poor entry population.
