# TRENDLINE_WAVE2_FAILURE: M15 state-machine reachability repair

## Durable finding

A single evaluation function imposed two mutually incompatible conditions on the same low/high pair: the entry into pullback state required continuation structure, while the later failure classification required an equal or reversing structure. Reapplying the first gate on every active-state evaluation made higher-low/lower-high and related failure paths unreachable.

## Repair discipline

Freeze the structure that justified a state transition. Later states should evaluate only information that arrived after the frozen anchor. Entry-only filters should not be allowed to suppress setup detection. If a failed pattern is itself invalidated by a new confirmed extreme, re-anchor the local pattern instead of deleting the higher-timeframe setup.

## Evidence

- [Implementation and 2024 report](../../reports/backtest/runs/20260815_trendline_wave2_failure_m15_state_fix_final/final-report.md)
- [Funnel comparison](../../reports/backtest/runs/20260815_trendline_wave2_failure_m15_state_fix_final/funnel_comparison_2024.csv)
- [Causality audit](../../reports/backtest/runs/20260815_trendline_wave2_failure_m15_state_fix_final/causality_audit_2024.csv)

## Current limitation

The locked 2024 window contained no M15 anchor after the sole H1 reversal-leg setup. The six deterministic transition tests prove code-path reachability, but a market-data occurrence is still required before assessing execution quality or expectancy.

