# 2026-06-02 - Multi-Currency Score Scanner Phase 2

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: add M5 new-bar scan gating, research branch controls, and a first Dow/fractal structure gate.
- Purpose: reduce backtest runtime and isolate whether the 2025 negative expectancy is caused by direction, symbol, or structure quality.

## Changes

- Changed `InpScanSeconds` default to `300`.
- Added `InpScanOnlyOnNewExecutionBar=true`.
- Added new execution-bar scan gating inside `OnTimer`, while keeping timer-driven operation.
- Added scan diagnostics CSV rows for executed and skipped scans.
- Added branch controls:
  - `InpTradeDirectionMode`
  - `InpDisableUsdJpyShort`
  - `InpSymbolResearchMode`
- Added `InpUseDowFractalStructureFilter=false` and related swing/pullback/reclaim diagnostics.
- Kept the CTrade bridge, base risk sizing, score model, TP, and SL placement unchanged.
- Added phase 2 presets and tester configs under `reports/presets/` and `reports/backtest/`.
- Added phase 2 runner and analyzer scripts:
  - `scripts/run_multicurrency_score_scanner_phase2_backtests.ps1`
  - `scripts/analyze_multicurrency_score_scanner_phase2.py`

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner.log`
- Compile result: `0 errors, 0 warnings`
- 2025 phase 2 runs completed:
  - A: BOTH + M5 new-bar scan
  - B: LONG_ONLY + M5 new-bar scan
  - C: SHORT_ONLY + M5 new-bar scan
  - D: LONG_ONLY + Dow/fractal structure + M5 new-bar scan
  - E: XAUUSD_ONLY + LONG_ONLY + Dow/fractal structure + M5 new-bar scan
  - F: BOTH + disabled USDJPY SHORT + M5 new-bar scan

## Evidence

- Research summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_summary.md`
- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_run_comparison.csv`
- Direction aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_direction.csv`
- Symbol aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_symbol.csv`
- Score-band aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_score_band.csv`
- Structure diagnostics: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_structure_filter_summary.csv`

## Result

- A/BOTH + 5m remained negative: `PF 0.982`, `Expected Payoff -0.44`, `Net -750.91`, `Max DD 36.06%`.
- M5 new-bar scan reduced the recorded A-run time to `3804s` versus the previous no-stop run record of about `5578s`, without materially changing the strategy behavior.
- B/LONG_ONLY was positive: `PF 1.109`, `Expected Payoff 3.19`, `Net 3777.82`.
- C/SHORT_ONLY was structurally negative: `PF 0.817`, `Expected Payoff -4.53`, `Net -3428.37`.
- D/LONG_ONLY + structure was cleaner: `PF 1.159`, `Expected Payoff 4.96`, `Net 3349.91`, `Max DD 6.64%`.
- E/XAUUSD_ONLY + LONG_ONLY + structure was strongest per trade but fully concentrated in XAUUSD.
- F/removing USDJPY short flipped net positive, but remaining short exposure still lost money.

## Decision

- The current BOTH scanner should not be promoted as a live candidate.
- The current SHORT branch should be parked or rebuilt independently.
- The next research branch should focus on `LONG_ONLY + DowFractalStructureFilter`, with `XAUUSD_ONLY + LONG_ONLY + DowFractalStructureFilter` tracked as a high-concentration reference branch.
- `EURJPY` LONG and high-score bands above `75` need separate diagnostics before any parameter optimization.
