# Release Packet: `btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2`

- Date: `2026-03-31`
- Status: `demo-forward candidate`
- Family status: `secondary live-track candidate`
- Owner: `CEO / repo operator`
- Next quarterly review: `2026-06-30`

## Candidate

- EA:
  - `mql/Experts/btcusd_20260330_session_meanrev.mq5`
- Preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.set`
- 1-year MT5 actual run:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-131610-294712-btcusd-20260330-session-meanrev-.json`

## Actual MT5 Baseline

- Net profit:
  - `+177.86`
- Profit factor:
  - `1.49`
- Trades:
  - `70`
- Max drawdown:
  - `1.58%`
- Expected payoff:
  - `2.54`

## Recent OOS Check

- Latest available recent MT5 OOS window:
  - `2026-01-01` to `2026-03-30`
- Recent OOS run:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-04-01-132317-215883-btcusd-20260330-session-meanrev-.json`
- Recent OOS metrics:
  - `net +92.29`
  - `PF 4.11`
  - `15` trades
  - `max DD 0.26%`
- Interpretation:
  - quality remained strong in the latest quarter,
  - but trade count stayed low, so this remains a quality-first secondary live-track candidate rather than the repo's long-term higher-turnover objective.

## Next Capital Stage

- First real-capital preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set`
- First real-capital packet:
  - `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.md`
- Staged 1-year MT5 actual:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-132810-116558-btcusd-20260330-session-meanrev-.json`
- Staged 1-year metrics:
  - `net +57.75`
  - `PF 1.41`
  - `70` trades
  - `max DD 0.69%`
- Route:
  - `guarded2` stays the demo-forward candidate,
  - the first real-capital deployment should use `smalllive015`, not the full `guarded2` risk, unless an override is recorded.

## Strategy Shape

- Symbol / timeframe:
  - `BTCUSD / M5`
- Direction:
  - `long-only`
- Entry window:
  - `20:00-24:00`
- Weekdays:
  - `0,1,2,3,4,6`
- Blocked entry hour:
  - `3`
- Entry idea:
  - stacked-bull trend filter, then buy deep late-session pullbacks when `RSI14 <= 37` and price is `1.50 ATR` below the fast mean.
- Exit idea:
  - variable mean-reversion exit, not fixed take-profit.
  - primary release is `EMA20 - 0.30 ATR` recovery or `12` bars time stop.

## Risk Doctrine

- Sizing:
  - `0.35%` of current equity per trade via the EA sizing function.
- Emergency stop:
  - `4.0 ATR`
- Daily hard stop:
  - `3.0%` of equity, with protective flatten enabled.
- Equity drawdown cap:
  - `12.0%`, with protective flatten enabled.
- Position caps:
  - `max_open_trades=2`
  - `max_open_per_side=2`
- Daily trade cap:
  - `20`

## Broker and Execution Assumptions

- Broker path used in current testing:
  - `XMTrading MT5`
- Spread gate:
  - `max_spread_pips=2500`
- Deviation:
  - `max_deviation_pips=250`
- This candidate is only valid if demo/live spread and slippage stay close to the assumptions above.

## Reproducibility

- Compile:
  - `powershell -ExecutionPolicy Bypass -File scripts/compile.ps1 -MetaEditorPath "C:\Program Files\XMTrading MT5\MetaEditor64.exe" -Source mql\Experts\btcusd_20260330_session_meanrev.mq5`
- Re-run MT5 tester:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2-1y.ini`
- Prepare the demo-forward packet:
  - `powershell -ExecutionPolicy Bypass -File scripts/prepare-demo-forward.ps1`
- Start a unique demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-demo-forward.ps1`
- Launch artifact:
  - `reports/live/<date>-<preset>-demo-forward-<timestamp>-launch.json`
- Review demo-forward telemetry:
  - `powershell -ExecutionPolicy Bypass -File scripts/review-forward-telemetry.ps1`
- Evaluate the forward promotion gate:
  - `powershell -ExecutionPolicy Bypass -File scripts/evaluate-forward-gate.ps1`
- Close the demo-forward run and refresh the preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/close-demo-forward.ps1 -ManifestPath <launch-manifest.json>`
- Run the live preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/live-preflight.ps1`
- Review live or demo state from telemetry + gate + heartbeat:
  - `powershell -ExecutionPolicy Bypass -File scripts/review-live-state.ps1`
- Review and apply the recommended operator action with an audit artifact:
  - `powershell -ExecutionPolicy Bypass -File scripts/act-on-live-review.ps1`

## Telemetry and Review Artifacts

- Telemetry file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_bull37_long_h12_live035_guarded2.csv`
- Operator command file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_operator.txt`
- Status snapshot file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_status.txt`
- Status heartbeat cadence:
  - `60 seconds` in demo/live runtime
- Baseline summary:
  - `reports/telemetry/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json`
- Baseline note:
  - `knowledge/experiments/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.md`

## Promotion Gate

- Required before any small-live discussion:
  - the latest available 3-month MT5 OOS check is archived with exact dates,
  - at least one demo-forward review written from the telemetry script,
  - at least one forward gate report written from the gate evaluator,
  - no unexpected rule violations,
  - no broker-side spread or slippage regime materially worse than the test assumptions,
  - realized demo-forward behavior remains consistent with the actual MT5 baseline.
- Required before any first-capital deployment:
  - the guarded2 demo-forward gate is `pass`,
  - the staged small-live preset is selected as the first-capital profile,
  - `scripts/small-live-preflight.ps1` returns `pass` or an explicitly accepted `review`.

## Rollback Triggers

- Immediately downgrade to `demo-only` if:
  - weekly realized PF drops below `1.0`,
  - slippage exceeds the current assumption for `5` trading days,
  - protective flatten triggers from equity cap or daily loss cap unexpectedly often,
  - broker behavior invalidates the spread gate assumption.

## Operator Actions

- Pause new entries:
  - `powershell -ExecutionPolicy Bypass -File scripts/set-ea-operator-mode.ps1 -Mode pause`
- Flatten positions and keep the EA paused:
  - `powershell -ExecutionPolicy Bypass -File scripts/set-ea-operator-mode.ps1 -Mode flatten`
- Return to normal:
  - `powershell -ExecutionPolicy Bypass -File scripts/set-ea-operator-mode.ps1 -Mode normal`
- Inspect current live heartbeat:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_status.txt`
- Read the heartbeat in a human-friendly format:
  - `powershell -ExecutionPolicy Bypass -File scripts/read-ea-status.ps1`
- Apply the recommended operator mode from the live review:
  - `powershell -ExecutionPolicy Bypass -File scripts/review-live-state.ps1 -ApplyRecommendedMode`
- Apply the latest live review and leave an action artifact:
  - `powershell -ExecutionPolicy Bypass -File scripts/act-on-live-review.ps1`

## Notes

- This is the best current deployable compromise.
- `live035` without the extra guards had better upside, but `guarded2` is the preferred first deployment profile because it preserves the edge while making capital controls explicit.
- `guarded2` is still not the first real-capital profile. It is the demo-forward proving preset.
- The first real-capital stage is intentionally smaller at `0.15%` equity risk per trade through `smalllive015`.
- Operator control and status heartbeat are active in demo/live, but automatically disabled in tester mode so reproducibility and tester speed stay intact.
- Status heartbeat is timer-driven, so stale-file checks reflect terminal/runtime health rather than only the latest signal bar.
- The latest recent OOS review is recorded at `knowledge/experiments/2026-04-01-btcusd-session-meanrev-oos-2026q1-review.md`.
