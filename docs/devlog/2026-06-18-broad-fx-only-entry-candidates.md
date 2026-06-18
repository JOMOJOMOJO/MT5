# 2026-06-18 - Broad FX-only Entry Candidates

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: test a broader FX-only candidate generation mode for 2025 by reducing hard gates.
- Scope: 2025 full-year FX-only, no XAUUSD, both directions, no Friday stop, no pair exclusion, no RewardR/SL/TP/risk/spread guard change, no optimization.

## Changes

- Added `RESEARCH_STRATEGY_NESTED_BROAD_FX_ENTRY_CANDIDATES`.
- Added M15 reversal diagnostics:
  - `cond_m15_micro_break`
  - `cond_m15_short_ma_reversal`
  - `cond_m15_candle_reversal`
- Added runner scenario set: `BroadFxEntryCandidates`.
- Added analysis script: `scripts/analyze_broad_fx_only_2025_entry_candidates.py`.

## Broad Candidate Rules

- Hard gates are reduced to:
  - H1 pullback / counter move observed.
  - M15 reversal candidate observed.
- H4 MA bias, H4 fib, H1 counter N-wave, H1 counter wave ATR, true BOS level, M15 BOS type, room_to_1r, room_to_2r, and round-number room are diagnostics only.

## Verification

- Compile log: [`reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_compile.log`](../../reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_compile.log)
- Compile result: `0 errors, 0 warnings`
- Backtest run: `fxbroad2025_A_broad_fx_entry_candidates`
- Symbols: `USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD`
- Period: 2025-01-01 to 2025-12-31

## Evidence

- Summary: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_summary.md`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_summary.md)
- Comparison: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_comparison.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_comparison.csv)
- Trades: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_trades.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_trades.csv)
- LONG failure summary: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_long_failure_summary.md`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_long_failure_summary.md)
- MT5 report: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fxbroad2025_A_broad_fx_entry_candidates_report.html`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fxbroad2025_A_broad_fx_entry_candidates_report.html)

## Result

- Current Broad FX-only: `63` trades, PF `0.737`, avg_R `-0.190`, net `-603.67`.
- Hard-gate reduced broad pool: `3999` trades, PF `0.826`, avg_R `-0.096`, net `-9227.62`.
- Broad + room_to_2r: `3168` trades, PF `0.783`, avg_R `-0.110`, net `-9365.09`.
- Broad + H4 MA bias: `1431` trades, PF `0.903`, avg_R `-0.184`, net `-1804.76`.
- Broad + M15 close BOS: `88` trades, PF `0.622`, avg_R `0.107`, net `-394.44`.
- Broad + room_to_2r + H4 MA bias: `1063` trades, PF `0.829`, avg_R `-0.234`, net `-2469.37`.

## Decision

- The candidate pool expanded as intended: `3999` vs `63` trades.
- The expanded pool has no fixed-BT candidate. PF remains below `1.0` across requested scenarios.
- `room_to_2r` was useful in the prior narrow pool, but it does not survive as a broad-pool filter.
- The top LONG failure in the broad pool is `bad_h4_bias`, followed by `m15_false_bos` and `pullback_not_finished`.
- The next useful diagnostic is not another simple hard gate. The broad pool shows that H4 direction/context quality and M15 reversal quality need to be separated before any fixed rule is promoted.
