# 2026-06-17 - Structural BOS V2 Pivot Sequence Validation

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Added research mode: `RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS_V2`
- Purpose: replace the thin latest-pivot Structural BOS v0 definition with fixed H4/H1 pivot-sequence validation.
- Scope: fixed-rule short diagnostic only. No Friday stop, symbol exclusion, direction-only branch, parameter optimization, RewardR change, SL/TP redesign, risk change, spread guard change, timeframe change, or annual BT.

## Implementation

V2 is independent from v0 and keeps existing execution/risk functions.

- H4 uses a three-pivot sequence:
  - Long: `A_low -> B_high -> C_low`, with `C > A`.
  - Short: `A_high -> B_low -> C_high`, with `C < A`.
- H4 impulse must be at least `1.5 * H4 ATR`.
- H4 correction still uses the fixed `38.2-61.8` zone.
- H1 counter N-wave uses a three-pivot sequence:
  - Long: `A_high -> B_low -> C_lower_high`.
  - Short: `A_low -> B_high -> C_higher_low`.
- H1 counter wave must be at least `1.0 * H1 ATR`.
- BOS level is the last H1 lower high for longs or last H1 higher low for shorts.
- M15 is only a closed-BOS confirmation aid; no new candle-quality threshold was added.
- Room-to-target is diagnosed with `room_to_1r`, `room_to_2r`, and `room_to_target_label`.

## Verification

- Compile log: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_v2_compile.log](../../reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_v2_compile.log)
- Compile result: `0 errors, 0 warnings`

## Short Backtests

Short-window V2 runs were added as `F_structural_bos_v2_all` for:

- `2025-02`
- `2025-08`
- `2025-10`
- `2026-Q1`

Comparison set:

- Nested instant all-candidates
- Context Router V2 all-candidates
- Structural BOS v0 all-candidates
- Structural BOS v2 all-candidates

## Result

Aggregate V2 result:

- Trades: `4`
- PF: `0.000`
- avg_R: `-1.004`
- Net: `-198.08`
- FX net: `-198.08`
- XAUUSD net: `0.00`
- LONG net: `-149.01`
- SHORT net: `-49.07`

V2 did not trade in `2025-02`, `2025-08`, or `2025-10`. In `2026-Q1`, it took four FX trades and all four lost.

Label split:

- `clean_structural_bos_v2`: `1` trade, avg_R `-1.000`, net `-49.07`
- `insufficient_room_to_target`: `3` trades, avg_R `-1.005`, net `-149.01`

## Gate Decision

Annual BT was not run.

Reasons:

- Trade count was too low.
- V2 did not beat v0 on PF or avg_R.
- V2 did not beat the best comparison branch.
- FX net was negative.
- Direction balance was weak.

## Interpretation

The stricter H4/H1 definition removed many weak candidates but did not uncover a positive edge. The remaining entries were either too close to H4 obstacles or still failed immediately. This confirms the failure audit direction: H4/H1 structure is the right area to inspect, but the current three-pivot fixed definition is not sufficient as an entry model.

Next work should not add an M15 candle threshold. If this family continues, it needs a richer H4/H1 structural model:

- full alternating pivot sequence, not only one A/B/C chain,
- explicit H1 countertrend exhaustion,
- target-side obstacle mapping before entry,
- clearer distinction between pullback completion and continuation noise.

## Evidence

- Summary: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_short_summary.md](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_short_summary.md)
- Comparison: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_short_comparison.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_short_comparison.csv)
- Trade rows: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_trade_rows.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_trade_rows.csv)
- By label: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_by_label.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_by_label.csv)
- By symbol: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_by_symbol.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_by_symbol.csv)
- By direction: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_by_direction.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_by_direction.csv)
- FX vs XAUUSD: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_fx_vs_xauusd.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_fx_vs_xauusd.csv)
- MFE/MAE/R reach: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_mfe_mae_r_reach.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_mfe_mae_r_reach.csv)
