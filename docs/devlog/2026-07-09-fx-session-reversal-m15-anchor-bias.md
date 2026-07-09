# FX Session Reversal Pullback: M15 Swing Anchor Bias

## Task

Added M15 oshiyasu/modoritakane anchor-bias diagnostics to `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` and compared them against the existing transcript-style M15 wave2 required-light and M5 pattern logic.

The goal was to test the video-style rule: keep a bullish view until the active oshiyasu is broken by a closed M15 bar, keep a bearish view until the active modoritakane is broken by a closed M15 bar, then wait for M5 pullback/retest style entries instead of jumping immediately.

## Implementation

- Added `InpUseM15SwingAnchorBias`, `InpM15SwingAnchorMode`, anchor break inputs, bias flip age, range mode, and coarse flip qualifiers.
- Built anchor state from confirmed M15 pivots only. No ZigZag repaint values or unclosed bars are used.
- Exported anchor state, active oshiyasu/modoritakane, break quality, N-state/range diagnostics, alignment, opposite-bias, and gate status into both signals and trades CSVs.
- Added batch generation, batch runner, and analyzer scripts for Q1 and full-2025 fixed validation.

## Evidence

- Summary: `reports/backtest/runs/20260709_session_reversal_m15_anchor_bias/summary.md`
- Full comparison: `reports/backtest/runs/20260709_session_reversal_m15_anchor_bias/full2025_comparison.csv`
- Trade CSV: `reports/backtest/runs/20260709_session_reversal_m15_anchor_bias/trades_all_scenarios.csv`
- Presets and tester INIs: `reports/presets/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_anchor_*.set` and `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_anchor_*.ini`

## Results

- Baseline reproduced: 318 trades, PF 0.59, avg_R -0.1582.
- Required-light reproduced: 50 trades, PF 1.34, avg_R +0.1099.
- Anchor aligned improved baseline slightly but remained negative: 222 trades, PF 0.65, avg_R -0.1327.
- Anchor opposite separated a worse group: diagnostic opposite had PF 0.49, avg_R -0.1916.
- Required-light OR anchor flip increased count to 145 trades but stayed negative: PF 0.79, avg_R -0.0760.
- M5 pattern and corrective exhaustion qualifiers did not rescue the OR variant.
- Range blocking worsened results; range diagnostic was less bad than non-range, so range is not a valid no-trade filter here.
- No full-2025 shallow gate pass. No 3-year BT/OOS was run.

## Decision

M15 anchor bias is useful as a diagnostic lens, especially to identify opposite-bias weakness, but it is not a sufficient promotion filter for this EA family. The only positive fragment remains the small M15 wave2 required-light set; it is below the trade-count threshold and should not be promoted.
