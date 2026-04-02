# Release Packet: `usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded`

- Date: `2026-04-02`
- Status: `demo-forward candidate`
- Family status: `turnover-biased long-only live-track candidate with parallel bucket entries`
- Owner: `CEO / repo operator`
- Reusable lessons:
  - `knowledge/patterns/2026-04-01-live-ready-definition.md`
  - `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`

## Candidate

- EA:
  - `mql/Experts/usdjpy_20260402_round_continuation_long.mq5`
- Preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.set`
- Long-window actual run:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-192837-849112-usdjpy-20260402-round-continuati.json`

## Long-Window Actual

- Window:
  - `2025-04-01` to `2025-12-31`
- Net profit:
  - `+563.31`
- Profit factor:
  - `1.28`
- Trades:
  - `145`
- Max drawdown:
  - `3.06%`

## Recent OOS Check

- Window:
  - `2026-01-01` to `2026-03-31`
- OOS run:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-192748-350119-usdjpy-20260402-round-continuati.json`
- OOS metrics:
  - `net +160.12`
  - `PF 2.06`
  - `20` trades
  - `max DD 0.38%`
- Interpretation:
  - this is the first `USDJPY long-only` branch in this family to clear the user's `~20 trades over 3 months` line without damaging recent OOS quality,
  - but it is still far below the desired `~1 trade/day` operating cadence.

## Strategy Shape

- Symbol / timeframe:
  - `USDJPY / M15`
- Direction:
  - `long-only`
- Parallel bucket model:
  - up to `3` managed positions can coexist,
  - only `1` open position per bucket at a time,
  - later buckets may enter even if an earlier bucket already has a live trade.
- Buckets:
  - `round quality`: `EMA13 > EMA100`, higher highs / higher lows, 50-pip anti-chop, wick-dominant pullback
  - `EMA continuation sidecar`: `EMA13 > EMA100`, positive slow slope, low-ADX London dip continuation
- Exit idea:
  - bucket-specific fixed stop / R target with a time stop
  - round bucket: `22 pips stop`, `1.5R`, `18 bars hold max`
  - EMA sidecar: `15 pips stop`, `1.2R`, `12 bars hold max`

## Risk Doctrine

- Sizing:
  - `0.30%` of current equity per trade
- Micro-cap override:
  - allowed up to `1.50%` when balance is `<= 150 USD`
- Min-lot guard:
  - skip the trade if broker minimum lot would force more than `2.0%` effective risk
- Daily hard stop:
  - `4.0%` of equity, with protective flatten enabled
- Equity drawdown cap:
  - `12.0%`, with protective flatten enabled
- Daily trade cap:
  - `4`

## Telemetry and Operator Files

- Telemetry baseline:
  - `reports/telemetry/2026-04-02-usdjpy-quality12b-stack-parallel-guarded-baseline.json`
- Forward gate baseline:
  - `reports/forward/2026-04-02-usdjpy-quality12b-stack-parallel-guarded-forward-gate.json`
- Telemetry file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_quality12b_stack_parallel_guarded.csv`
- Operator file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_stack_parallel_operator.txt`
- Status file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_stack_parallel_status.txt`
- Heartbeat cadence:
  - `60 seconds` in demo/live runtime

## Reproducibility

- Compile:
  - `powershell -ExecutionPolicy Bypass -File scripts/compile.ps1 -MetaEditorPath "C:\Program Files\XMTrading MT5\MetaEditor64.exe" -Source mql\Experts\usdjpy_20260402_round_continuation_long.mq5`
- Re-run long-window actual:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded-train-9m.ini`
- Re-run recent OOS:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded-oos-3m.ini`
- Launch a demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-usdjpy-quality12b-stack-parallel-demo-forward.ps1`
- Close the demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/close-usdjpy-quality12b-stack-parallel-demo-forward.ps1 -ManifestPath <launch-manifest.json>`
- Run the live preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/usdjpy-quality12b-stack-parallel-live-preflight.ps1`

## Promotion Gate

- Required before any first-capital discussion:
  - compile stays clean,
  - long-window actual and latest OOS artifacts remain positive,
  - at least one real demo-forward review is written,
  - at least one non-self-check forward gate is written,
  - no unexpected rule violations,
  - realized spread / slippage stays close to the tested assumptions.

## Notes

- This replaces `quality12b_stack_guarded` as the active turnover-biased `USDJPY long-only` demo-forward candidate.
- `quality12b_guarded` remains the quality-first anchor.
- The key change is structural, not parametric: turnover improved because the EA no longer blocks every later bucket behind the first open trade.
