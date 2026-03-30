# BTCUSD optimization workflow for repo-managed presets

- Date: 2026-03-30
- EA: btcusd_20260124
- Symbol: BTCUSD
- Timeframe: M1

## Goal

Move MT5 parameter search out of implicit terminal state and into repo-managed preset files.

## Repo artifacts

- Single-test preset: `reports/presets/btcusd_20260124-baseline.set`
- Search preset: `reports/presets/btcusd_20260124-search.set`
- Search config: `reports/optimization/optimizer-short.ini`
- Long validation config: `reports/backtest/validation-1y.ini`
- Explicit OOS config: `reports/backtest/oos-3m.ini`

## Decision

- Use MT5 optimization only for short search windows.
- Freeze the chosen preset and re-run it on long validation and OOS windows.
- Treat any candidate that fails long validation or OOS as a strategy-design problem, not a final-stage tuning problem.

## Notes

The current BTCUSD baseline already fails long validation and OOS badly, so the search workflow is now infrastructure, not proof that this algorithm is acceptable.
