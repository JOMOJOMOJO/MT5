# Release Packet: `btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015`

- Date: `2026-03-31`
- Status: `small-live staged preset`
- Family status: `secondary live-track candidate`
- Owner: `CEO / repo operator`
- Next quarterly review: `2026-06-30`

## Candidate

- EA:
  - `mql/Experts/btcusd_20260330_session_meanrev.mq5`
- Preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set`
- Required proving packet:
  - `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md`
- 1-year MT5 actual run:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-132810-116558-btcusd-20260330-session-meanrev-.json`

## Actual MT5 Baseline

- Net profit:
  - `+57.75`
- Profit factor:
  - `1.41`
- Trades:
  - `70`
- Max drawdown:
  - `0.69%`
- Expected payoff:
  - `0.83`

## Role

- This is not the proving preset.
- `guarded2` remains the demo-forward proving preset because it exercises the full live guard path.
- `smalllive015` is the first real-capital preset after the guarded2 demo-forward gate passes.

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
  - `0.15%` of current equity per trade via the EA sizing function.
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

## Promotion Gate

- Required before the first small-live launch:
  - at least one real guarded2 demo-forward review exists,
  - at least one guarded2 forward gate report exists,
  - `scripts/small-live-preflight.ps1` returns `pass` or an explicitly accepted `review`,
  - the broker-side spread and slippage regime still match the MT5 assumptions closely enough,
  - the small-live capital amount is intentionally limited.

## Reproducibility

- Compile:
  - `powershell -ExecutionPolicy Bypass -File scripts/compile.ps1 -MetaEditorPath "C:\Program Files\XMTrading MT5\MetaEditor64.exe" -Source mql\Experts\btcusd_20260330_session_meanrev.mq5`
- Re-run MT5 tester:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015-1y.ini`
- Prepare the small-live packet:
  - `powershell -ExecutionPolicy Bypass -File scripts/prepare-small-live.ps1`
- Run the small-live preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/small-live-preflight.ps1`
- Start the first-capital cycle only after the staged preflight clears:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-small-live.ps1`
- Launch artifact:
  - `reports/live/<date>-<preset>-small-live-<timestamp>-launch.json`
- Review live or demo state from telemetry + gate + heartbeat:
  - `powershell -ExecutionPolicy Bypass -File scripts/review-live-state.ps1`
- Start a unique small-live telemetry cycle:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-demo-forward.ps1 -BasePresetPath reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set -RunLabel small-live`
- Close the small-live telemetry cycle:
  - `powershell -ExecutionPolicy Bypass -File scripts/close-demo-forward.ps1 -ManifestPath <launch-manifest.json>`

## Telemetry and Controls

- Telemetry file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_bull37_long_h12_smalllive015.csv`
- Operator command file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_operator.txt`
- Status snapshot file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_status.txt`
- Status heartbeat cadence:
  - `60 seconds` in demo/live runtime
- Recommended operator action:
  - `powershell -ExecutionPolicy Bypass -File scripts/review-live-state.ps1 -ApplyRecommendedMode`
- Review + action with an audit artifact:
  - `powershell -ExecutionPolicy Bypass -File scripts/act-on-live-review.ps1`

## Rollback Triggers

- Immediately downgrade to `demo-only` if:
  - weekly realized PF drops below `1.0`,
  - live slippage materially exceeds the current assumption for `5` trading days,
  - protective flatten triggers from daily or equity caps in a way not seen during demo,
  - broker behavior invalidates the spread gate assumption.

## Notes

- This packet exists to keep the first real-capital stage intentionally smaller than the proving preset.
- The strategy logic is unchanged from guarded2. The main difference is the smaller equity risk per trade.
