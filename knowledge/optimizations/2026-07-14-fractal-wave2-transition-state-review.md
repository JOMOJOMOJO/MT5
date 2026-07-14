# Fractal Wave2 State-Machine Findings

## Fixed Comparison

- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD
- Tester: M15 / Model 4 / 2025 Q1 and full year / deposit 10000
- Internal: H1 diagnostic, M15 parent, M5 child closed-bar scan
- Wave2 modes: first opposite close, confirmed terminal pivot, M5 countertrend start
- Exit constants: 1.3R target, child or parent wave2 extreme stop
- No session, symbol, direction, weekday, H1/H4 hard gate, or fine threshold repair

Evidence: [summary](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/summary.md), [comparison](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/full2025_comparison.csv), [funnel](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/funnel_breakdown.csv).

## Reusable Findings

1. A confirmation-wait state must own its event. Recomputing and replacing the parent candidate every scan prevented Mode 1 from ever reaching terminal-pivot confirmation.
2. The latest valid child anchor materially changes event identity. The legacy diagnostic produced 795 full-year flips against anchors that were no longer latest valid; latest mode produced only latest-anchor trades.
3. Correct structure does not imply edge. Mode 0/1/2 all converged near PF 0.69-0.70 and MFE>=1R near 20%.
4. Mode 2 funnel was 3142 fresh flips -> 174 valid candidates -> 173 trades. Candidate invalid was mainly spread guard 2562 and stop distance 406. These are execution-validity losses, not portfolio rejection.
5. Parent-stop increased MFE>=1R to 35.5%, but only 31 trades remained and PF was 0.99. This is a low-count diagnostic fragment, not a promotion candidate.
6. Signal reservation must follow technical validation but precede portfolio comparison. Invalid data/SL/spread and portfolio rejection need different lifecycle labels.

## Decision

No research-continuation or 2025 shallow-gate candidate. Do not continue with 3-year/OOS or repair through spread thresholds, stop thresholds, symbol/direction/session exclusion, or TP/BE optimization. Keep the corrected state-machine code as a reusable implementation asset and keep the strategy family parked.
