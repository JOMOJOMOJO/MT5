# Structural BOS Failure Audit

This audit uses existing short-period Structural BOS artifacts only. It does not change EA order logic, SL/TP, RewardR, risk, CTrade, spread guard, timeframe, symbol filters, direction filters, or run annual BT.

## Scope

- Strategy: `RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS`
- Periods: `2025-02`, `2025-08`, `2025-10`, `2026-Q1`
- Data source: existing nested signal/trade diagnostics and Structural BOS short comparison outputs
- MT5 M15 rate lookup for time-to-R fields: `True`

## Aggregate Result

- Trades: `13`
- PF: `0.367`
- Expected payoff: `-26.38`
- Net: `-342.94`
- clean_structural_bos: `7` trades, PF `0.339`, net `-197.0`
- chasing_entry: `4` trades, PF `0.664`, net `-49.43`

## Why 2025-08 / 2025-10 Had No Orders

- The summary counters show most evaluations died before a usable H4/H1 setup: `no_h4_nwave` was the dominant counter in both windows.
- 2025-08 `no_h4_impulse`: `19960`
- 2025-08 `no_h1_counter_nwave`: `996`
- 2025-08 `no_m15_bos`: `438`
- 2025-10 `no_h4_impulse`: `20330`
- 2025-10 `no_h1_counter_nwave`: `972`
- 2025-10 `no_m15_bos`: `431`
- For 2025-10, only a few final candidates reached logged blocked-candidate status, and all were blocked by spread guard after the H1/M15 structural checks. This means the zero-order outcome is mostly setup scarcity plus execution blocking, not simply a lack of price movement.

## Clean Structural BOS Failure

- `clean_structural_bos` was not clean in performance terms. It mostly avoided the explicit chasing labels but still failed after entry.
- The losing clean samples show valid-looking H1/M15 BOS labels, but MFE was generally too weak or the stop was reached before enough follow-through.
- This points to H4/H1 structure definition weakness rather than an M15 confirmation-only problem.

## H1 BOS Level Audit

- `h1_bos_level_too_old`: `5`
- `h1_bos_level_valid`: `8`

Interpretation: the current BOS level is often mechanically valid according to the latest pivot comparison, but the diagnostics cannot prove it is a meaningful countertrend N-wave invalidation line. The EA currently logs only compressed H1 high/low values, not the full pivot sequence.

## Pivot Sequence Audit

- `h1_counter_nwave_overextended`: `4`
- `h1_counter_nwave_valid`: `9`

The current logic is still too close to latest-pivot comparison. It can label an H1 counter N-wave as valid without proving a full three-point N-wave or trader stop cluster.

## Entry Timing Audit

- `bad_context_entry`: `3`
- `chasing_entry`: `4`
- `false_bos_entry`: `3`
- `good_timing`: `1`
- `late_entry`: `2`

## Judgement

1. Structural BOS v0 failed because the H4/H1 setup definition is too sparse and the H1 BOS level is only mechanically derived from recent pivots.
2. 2025-08 / 2025-10 had zero orders mainly because the setup filter generated almost no tradable candidates; 2025-10 also had spread-guard blocks on the few candidates that reached final diagnostics.
3. `clean_structural_bos` underperformed `chasing_entry` because clean only meant close to the BOS level, not that the H4/H1 N-wave structure was meaningful.
4. The H1 BOS level is not proven to be a true structural invalidation line from current diagnostics.
5. H4/H1 pivot sequence validation is the next weak point. M15 confirmation is secondary.
6. Structural BOS v2 is worth considering only if it first upgrades H4/H1 structure logging and validation: full pivot sequence, minimum wave size, countertrend N-wave depth, and next obstacle/room-to-target.

## Artifacts

- By reason: [by reason](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_by_reason.csv)
- By label: [by label](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_by_label.csv)
- H1 BOS level audit: [H1 BOS level audit](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_h1_bos_level_audit.csv)
- Pivot sequence audit: [pivot sequence audit](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_pivot_sequence_audit.csv)
- Entry timing audit: [entry timing audit](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_entry_timing_audit.csv)
- Rejection counter: [rejection counter](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_rejection_counter.csv)
- Clean losers sample: [clean losers sample](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_clean_losers_sample.csv)
- 2025-10 no trade sample: [2025-10 no trade sample](ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_2025_10_no_trade_sample.csv)
