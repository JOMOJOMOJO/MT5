# Session Reversal Pullback Fractal Timeframe Matrix Optimization Note

## Hypothesis

The prior H4/H1 confirmed wave3 alignment may be too rigid. A parameterized top/structure/entry timeframe layout could show whether H1/M15/M5 produces better first-pullback entries than the default H4/H1/M15/M5 layout.

## Implemented Test Matrix

- Period: 2025-01-01 to 2025-12-31
- TF/model/deposit: M15 / Model 4 / 10000 USD
- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD
- Runs: 72
- Scenarios:
  - `london_first120_reference`
  - `all_symbols_first120`
  - `one_symbol_first120`
  - `tokyo_first120_reference`
  - `newyork_first120_reference`
  - `clean_target_path_first120`
- Break-even modes:
  - `no_break_even`
  - `break_even_at_1_1R`

Matrix:

- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_timeframe_matrix_run_matrix_2025.csv`

## Execution Finding

No valid strategy conclusion was produced because MT5 did not complete a valid run after the preset issue was fixed.

Important detail:

- The first 9 HTML reports generated during the attempt were invalid. They used prior one-symbol inputs because the terminal profile read the EA-name `.set`, not the generated run-specific preset.
- `scripts/backtest.ps1` now copies the selected preset to both the run-specific preset name and the EA-name `.set` in each MT5 data folder containing the target `.ex5`.
- After the fix, D232 received the intended `InpLogFolder` and scenario values, but the terminal still stalled before EA initialization due to broker synchronization/authentication state.

## Decision

Do not interpret the current 72-row comparison as backtest evidence. It is an execution-blocked matrix scaffold.

Do not promote, reject, or tune the timeframe hypothesis until the matrix is rerun with valid MT5 reports and per-run trade CSVs.

## Next Validation Step

When MT5 synchronization is healthy:

1. Rerun `scripts/generate-session-reversal-timeframe-matrix.py` only if the matrix needs regeneration.
2. Run the 72 INIs with `scripts/backtest.ps1`.
3. Confirm each run creates a per-run Common Files folder named `fx_session_reversal_timeframes_{run_id}_2025`.
4. Run `scripts/analyze-session-reversal-timeframe-matrix.py`.
5. Promote only if a gate-scope scenario passes the 2025 shallow criteria.

## Evidence

- `docs/devlog/2026-06-28-session-reversal-pullback-fractal-timeframe-matrix.md`
- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/summary.md`
- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/comparison.csv`
- `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_timeframe_matrix_compile.log`
