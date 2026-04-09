# USDJPY round quality guarded kickoff

- Date: `2026-04-09`
- Family: `usdjpy_20260409_round_quality_guarded`
- Status: `compile and first actual MT5 validation complete`
- Roles applied:
  - `research-director`
  - `systematic-ea-trader`
  - `risk-manager`
  - `professional-trader`

## Why This EA Exists

- The repo's current `USDJPY` quality anchor is `quality12b_guarded`.
- The existing `usdjpy_20260402_round_continuation_long.mq5` file is also the research hub for rejected sidecars and experimental buckets.
- This new EA extracts the most defensible `quality-first` long setup into a standalone operational shell:
  - one symbol,
  - one timeframe,
  - one entry thesis,
  - explicit live guards,
  - explicit operator controls,
  - reproducible tester configs.

## Reused Company Lessons

- `knowledge/patterns/2026-03-31-expectancy-compounding-doctrine.md`
- `knowledge/patterns/2026-04-01-live-ready-definition.md`
- `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`

## Strategy Shape

- Symbol / timeframe:
  - `USDJPY / M15`
- Direction:
  - `long-only`
- Entry thesis:
  - `EMA13 > EMA100`
  - recent `HH / HL` structure confirmed by pivots
  - recent volatility window crosses at least one `50 pip` zone
  - entry bar is a wick-dominant pullback, not a chase candle
  - price stays above the latest structural low and above `EMA100`
- Exit model:
  - fixed `22 pip` stop
  - fixed `1.5R` target
  - `18 bar` time stop

## Risk Map

- Per-trade default risk:
  - `0.50%` of equity
- Micro-cap override:
  - `1.25%` only when equity is `<= 150 USD`
- Min-lot oversize guard:
  - skip if minimum lot would force more than `2.0%` effective risk
- Daily hard-loss cap:
  - `3.0%`, with flatten enabled
- Equity drawdown kill-switch:
  - `8.0%`, with flatten enabled
- Consecutive loss cooldown:
  - pause entries after `2` consecutive losses
  - resume after `8` completed `M15` bars
- Daily trade cap:
  - `2`

## Operational Additions

- telemetry CSV in `FILE_COMMON`
- operator `pause / flatten` command file in `FILE_COMMON`
- status heartbeat snapshot in `FILE_COMMON`
- stop-distance validation uses both broker stop level and freeze level

## Reproducibility Artifacts

- EA:
  - `mql/Experts/usdjpy_20260409_round_quality_guarded.mq5`
- Baseline preset:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-baseline.set`
- Train config:
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-train-9m.ini`
- OOS config:
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-oos-3m.ini`

## Validation Intent

- First gate:
  - compile cleanly
- Second gate:
  - long-window MT5 run on `2025-04-01` to `2025-12-31`
- Third gate:
  - untouched OOS MT5 run on `2026-01-01` to `2026-04-01`

## First Actual MT5 Results

- Compile:
  - `reports/compile/metaeditor.log`
- Train run:
  - `reports/backtest/imported/usdjpy_20260409_round_quality_guarded-train-9m-m15.htm`
  - `net +619.81`
  - `PF 1.50`
  - `59 trades`
  - `balance DD 2.22%`
- OOS run:
  - `reports/backtest/imported/usdjpy_20260409_round_quality_guarded-oos-3m-m15.htm`
  - `net +85.13`
  - `PF 2.13`
  - `9 trades`
  - `balance DD 0.62%`

## Readout

- The standalone extraction preserved the repo's `quality-first` shape:
  - positive long-window actual
  - positive recent OOS
  - low drawdown
- The turnover profile is still thin:
  - `59` trades over the `9 month` train window
  - `9` trades over the `2026-01-01` to `2026-04-01` OOS window
- Therefore this is a clean operational shell and a valid quality candidate, but it is still not a high-turnover mainline.

## Current Decision

- Keep this file as the standalone `quality-first` shell for controlled operation and future demo-forward packaging.
- Do not claim live readiness yet:
  - demo-forward has not been reviewed
  - first-capital staging has not been written for this exact file
