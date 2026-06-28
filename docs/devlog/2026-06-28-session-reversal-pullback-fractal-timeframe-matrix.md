# 2026-06-28 Session Reversal Pullback Fractal Timeframe Matrix

## Task

Parameterize `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` so the same EA can compare H4/H1/M15/M5 against H1/M15/M5-style structure without adding new research modes.

This follows:

- `docs/devlog/2026-06-27-session-reversal-pullback-htf-alignment-break-even-diagnostics.md`
- `knowledge/optimizations/2026-06-27-session-reversal-pullback-htf-prefilter-score-diagnostics.md`

## Implementation

- Added timeframe inputs:
  - `InpTopContextTF`
  - `InpStructureTF`
  - `InpPrimaryEntryTF`
  - `InpSecondaryEntryTF`
  - `InpUseSecondaryEntryTF`
  - `InpRequireStructureTFConfirmation`
  - `InpUseTopTFAsOppositeFilterOnly`
- Generalized the H4/H1 direction logic into top-context / structure-context logic while retaining legacy H4/H1 CSV aliases.
- Allowed primary and secondary entry candidates to be scored independently, selecting the higher-score first-pullback/retest candidate.
- Removed the first60 time score. Session windows remain gates and diagnostics.
- Added coarse fib pullback diagnostics and optional score/gate inputs:
  - `InpUseFibPullbackScore`
  - `InpRequireFibPullbackZone`
  - `InpFibPreferredMin`
  - `InpFibPreferredMax`
  - `InpFibDeepMax`
- Extended signals/trades/summary CSV fields with timeframe config, entry timeframe, fib zone, fib score, retest score, and target-room score diagnostics.
- Added:
  - `scripts/generate-session-reversal-timeframe-matrix.py`
  - `scripts/analyze-session-reversal-timeframe-matrix.py`

## Validation

- Compile: `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_timeframe_matrix_compile.log`
- Compile result: `0 errors, 0 warnings`.
- Generated 72 MT5 shallow BT configs:
  - 6 timeframe configs
  - 6 scenarios
  - 2 break-even modes
  - M15, Model 4, Deposit 10000

## Blocker

The 2025 matrix did not produce valid MT5 backtest evidence in this session.

Two separate issues were found:

- Preset application issue: MT5 was reading `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.set` from the terminal data profile, not the run-specific preset name. The first 9 generated HTML reports were therefore invalid because they reused the prior `session_reversal_pullback_one_symbol_first120` inputs. Those reports were removed from the evidence set.
- MT5 environment issue: after preset copying was fixed, the D232 terminal still stopped after `not synchronized with trade server` and did not reach EA `OnInit`. The tester log reached the `testing of Experts\dev\mql\Experts\ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.ex5` line but did not emit the expected `MetaTester started` / EA initialization lines.

`scripts/backtest.ps1` was updated to copy each preset both to the run-specific name and to the EA-name `.set` file in every MT5 data folder that contains the target `.ex5`. A short launch confirmed D232 now receives:

- `InpScenarioMode=6`
- `InpLogFolder=fx_session_reversal_timeframes_london_first120__current__no_be_2025`

## Decision

No strategy result or promotion decision can be made from this matrix yet. Treat the current run folder as an execution-blocked artifact, not as trading evidence.

Next valid step is to rerun the generated 72 configs only after MT5 account/history synchronization is healthy enough for the tester to reach EA initialization.

## Evidence

- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_timeframe_matrix_run_matrix_2025.csv`
- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/summary.md`
- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/comparison.csv`
- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/r_metrics.csv`
- `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_timeframe_matrix_compile.log`
