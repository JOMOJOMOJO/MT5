# 2026-06-17 - FX-only 2025 Condition Factorial

## Summary

- Task: rerun `RESEARCH_STRATEGY_NESTED_CONDITION_FACTORIAL_CANDIDATES` for 2025 with XAUUSD excluded, then analyze condition contribution on FX pairs only.
- Symbols: `USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD`.
- Period: `2025-01-01` to `2025-12-31`.
- No Friday stop, direction limit, pair exclusion, RewardR/SL/TP/risk/spread guard change, or parameter optimization was used.

## Changes

- Added `-SymbolsOverride` to `scripts/run_multicurrency_score_scanner_thirdwave_backtests.ps1` so research presets can override `InpSymbols` without changing EA logic.
- Added `scripts/analyze_fx_only_2025_condition_factorial.py` for:
  - FX-only executed candidate export.
  - Primary condition all-combination factorial ranking.
  - Single condition ON/OFF impact.
  - `room_to_2r` recheck with LONG/SHORT split.
  - Symbol/month/direction aggregates.
  - LONG failure-type breakdown.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_compile.log`
- Compile result: `0 errors, 0 warnings`
- MT5 run: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fxcf2025_A_condition_factorial_candidates_report.html`
- Elapsed: `407.6` seconds in `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fxcf2025_elapsed.csv`
- Scan driver: `USDJPY` in scan diagnostics.

## Results

- Broad FX-only candidates: `63` trades.
- Broad PF / avg_R / net: `0.737` / `-0.190` / `-603.67`.
- LONG / SHORT: `28` / `35` trades.
- LONG net / SHORT net: `-192.20` / `-411.47`.
- `cond_room_to_2r`:
  - ON: `28` trades, PF `1.121`, avg_R `0.079`, net `109.03`.
  - OFF: `35` trades, PF `0.488`, avg_R `-0.404`, net `-712.70`.
- No condition set met the strict next fixed-BT gate of `trades >= 60`, PF `> 1.1`, avg_R `> 0`, positive net, and balanced exposure.

## Decision

- `cond_room_to_2r` is still the strongest diagnostic condition, but it should remain a diagnostic/fixed-research candidate rather than a promoted hard gate.
- FX-only removes the previous XAUUSD drag, but it does not create a robust annual edge by itself.
- LONG is less broken than in the all-symbol annual Room2R run, but the broad FX candidate set remains negative.
- The next useful work is not parameter tuning. If continuing this family, inspect whether `room_to_2r` can be made structural rather than merely an obstacle-distance filter.

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_summary.md`
- Candidates: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_candidates.csv`
- All combinations: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_all_combinations.csv`
- Single effects: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_single_effects.csv`
- Room2R recheck: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_room2r_recheck.csv`
- LONG failure summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_long_failure_summary.md`
