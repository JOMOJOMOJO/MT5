# Release Packet: `usdjpy_20260402_round_continuation_long-quality12b_guarded`

- Date: `2026-04-02`
- Status: `demo-forward candidate`
- Family status: `quality-first secondary live-track candidate`
- Owner: `CEO / repo operator`
- Next quarterly review: `2026-07-02`

## Candidate

- EA:
  - `mql/Experts/usdjpy_20260402_round_continuation_long.mq5`
- Preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_guarded.set`
- Long-window actual run:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-165730-877395-usdjpy-20260402-round-continuati.json`

## Long-Window Actual

- Window:
  - `2025-04-01` to `2025-12-31`
- Net profit:
  - `+804.29`
- Profit factor:
  - `1.49`
- Trades:
  - `59`
- Max drawdown:
  - `2.91%`

## Recent OOS Check

- Window:
  - `2026-01-01` to `2026-04-01`
- OOS run:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-163430-849482-usdjpy-20260402-round-continuati.json`
- OOS metrics:
  - `net +343.11`
  - `PF 2.13`
  - `9` trades
  - `max DD 2.49%`
- Interpretation:
  - quality is strong enough for demo-forward proving,
  - but turnover is still thin, so this is not the repo's high-turnover mainline.

## Next Capital Stage

- First real-capital preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_smalllive050.set`
- First real-capital packet:
  - `.company/release/usdjpy_20260402_round_continuation_long-quality12b_smalllive050.md`
- Staged long-window actual:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-165730-841822-usdjpy-20260402-round-continuati.json`
- Route:
  - `quality12b_guarded` stays the demo-forward proving preset,
  - first capital should use `smalllive050`, not the proving preset.

## Strategy Shape

- Symbol / timeframe:
  - `USDJPY / M15`
- Direction:
  - `long-only`
- Entry idea:
  - `EMA13 > EMA100`, recent higher highs / higher lows, wick-dominant pullback, and 50-pip zone anti-chop.
- Entry quality:
  - `EMA13 distance <= 12 pips`
  - `upper wick >= 0.50`
  - `lower wick <= 0.10`
- Exit idea:
  - fixed stop / R target with a time stop.
  - current release uses `22 pips stop`, `1.5R target`, `18 bars hold max`.

## Risk Doctrine

- Sizing:
  - `0.65%` of current equity per trade.
- Micro-cap override:
  - allowed up to `2.0%` when balance is `<= 150 USD`.
- Min-lot guard:
  - skip the trade if broker minimum lot would force more than `2.0%` effective risk.
- Daily hard stop:
  - `6.0%` of equity, with protective flatten enabled.
- Equity drawdown cap:
  - `12.0%`, with protective flatten enabled.
- Daily trade cap:
  - `2`

## Micro-Capital Note

- This family is materially more micro-cap friendly than the BTC candidates.
- On the current USDJPY feed, `0.01 lot` can still express the stop distance in the intended first-capital range.
- Even so, first capital should start with the staged `smalllive050` preset and a real demo-forward review must pass first.

## Telemetry and Operator Files

- Telemetry baseline:
  - `reports/telemetry/2026-04-02-usdjpy-quality12b-guarded-baseline.json`
- Forward gate baseline:
  - `reports/forward/2026-04-02-usdjpy-quality12b-guarded-forward-gate.json`
- Telemetry file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_quality12b_guarded.csv`
- Operator file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_operator.txt`
- Status file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_status.txt`
- Heartbeat cadence:
  - `60 seconds` in demo/live runtime

## Reproducibility

- Compile:
  - `powershell -ExecutionPolicy Bypass -File scripts/compile.ps1 -MetaEditorPath "C:\Program Files\XMTrading MT5\MetaEditor64.exe" -Source mql\Experts\usdjpy_20260402_round_continuation_long.mq5`
- Re-run long-window actual:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/usdjpy_20260402_round_continuation_long-quality12b_guarded-train-9m.ini`
- Re-run recent OOS:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/usdjpy_20260402_round_continuation_long-quality12b_guarded-oos-3m.ini`
- Launch a demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-usdjpy-quality12b-demo-forward.ps1`
- Close the demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/close-usdjpy-quality12b-demo-forward.ps1 -ManifestPath <launch-manifest.json>`
- Run the live preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/usdjpy-quality12b-live-preflight.ps1`

## Promotion Gate

- Required before any small-live discussion:
  - compile stays clean,
  - long-window actual and latest OOS artifacts remain positive,
  - at least one real demo-forward review is written,
  - at least one non-self-check forward gate is written,
  - no unexpected rule violations,
  - realized spread/slippage stays close to the tested assumptions.

## Rollback Triggers

- Immediately downgrade to `demo-only` if:
  - weekly realized PF drops below `1.0`,
  - spread stays materially above the `2.0 pips` gate for multiple trading days,
  - daily loss cap or equity drawdown cap triggers unexpectedly often,
  - the forward gate degrades to `fail`.

## Notes

- This is the best current USDJPY long-only quality branch.
- It now satisfies the repo's long-window drawdown gate and is ready for `demo-forward proving`, not for direct first capital.
- It does not satisfy the repo's high-turnover objective by itself.
