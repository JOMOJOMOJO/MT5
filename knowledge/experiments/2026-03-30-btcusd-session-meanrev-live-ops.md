# BTCUSD Session Mean-Reversion: Live Operations Playbook

- Date: 2026-03-30
- EA: `btcusd_20260330_session_meanrev`
- Scope: `BTCUSD / M5 / short-focused`

## Baseline (Liveguards-Mid)

- Strategy core:
  - `short_dist=0.87`
  - `short_rsi=64-82`
  - `short_min_atr_pct=0.0003`
  - `hold_bars=14`
- Trading window:
  - `00:00-08:00` (server time)
  - weekdays: `0,1,2,3,4,6`
  - blocked hour: `3`
- Friction assumptions:
  - `max_spread_pips=2500`
  - `entry/exit slip=250`, `stop slip=400`
- Ops guards:
  - `daily_loss_cap_pct=3.0`
  - `max_trades_per_day=10`
  - `max_consecutive_losses=5`
  - `consecutive_loss_cooldown_bars=24`
  - `equity_drawdown_cap_pct=0` (implemented, default off)

## Evidence

- 80k validation (guarded):
  - `reports/research/2026-03-30-session-meanrev-validate/liveguards-mid-80k-b.json`
  - all: `4.80 trades/day`, `PF 1.20`
- 50k validation (guarded):
  - `reports/research/2026-03-30-session-meanrev-validate/liveguards-mid-50k-b.json`
  - all: `5.37 trades/day`, `PF 1.49`

## Go-Live Checklist

- Compile with `0 errors, 0 warnings`.
- MT5 HTML backtest report reproduces the same preset behavior.
- One forward-demo period completed with no rule violations.
- Broker-side spread/latency distribution is within assumed friction.
- Emergency stop procedure is tested (`EA disable + manual flatten`).

## Runtime Rules

- Stop new entries immediately when:
  - daily loss cap is hit,
  - consecutive-loss lock is active,
  - spread guard is violated.
- Keep open-position exit logic active even when new entries are blocked.
- If weekly PF drops below `1.0` or realized slippage exceeds assumptions for 5 trading days, downgrade to demo and review.

## Telemetry

- Runtime telemetry is enabled by default in the preset.
- Output file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_live.csv`
- Summary tool:
  - `python plugins/mt5-company/scripts/mt5_telemetry_summary.py --input <telemetry.csv> --output reports/telemetry/<name>.json --markdown-output knowledge/experiments/<name>.md`
- Logged events:
  - `entry`
  - `exit`
  - `loss_lock`
  - `daily_summary`
- Use the 1-week demo-forward run to review:
  - daily trade count,
  - losing-streak lock frequency,
  - blocked-entry reasons,
  - realized day-by-day net versus assumptions.

## Baseline Telemetry Snapshot

- MT5 report-backed baseline snapshot:
  - `reports/telemetry/2026-03-30-btcusd-session-meanrev-combined-m5.json`
  - `knowledge/experiments/2026-03-30-btcusd-session-meanrev-telemetry-baseline.md`
- Baseline readout:
  - `242` exits
  - `PF 1.7452`
  - `1.3908` entries/day
  - `84 / 174` active days
  - spread blocks: `33370`
- Interpretation:
  - the current guarded baseline is profitable, but real MT5 trade frequency is much lower than the optimistic Python validator estimate,
  - spread gating is the largest blocker in the current live-like setup.

## Higher-Turnover Branch

- New combo candidate:
  - preset: `reports/presets/btcusd_20260330_session_meanrev-combo15_35_h12.set`
  - note: `knowledge/experiments/2026-03-31-btcusd-session-meanrev-combo-bucket.md`
- Strategy shape:
  - keep the proven `asia short` core,
  - add `late-session long` with `long_dist=1.50`, `long_rsi_max=35`, `hold_bars=12`.
- MT5 combined-window result:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-000240-833419-probe-combo-asia-short-late-long.json`
  - `net +212.61`
  - `PF 1.46`
  - `392` trades
  - `max DD 0.69%`
- Interpretation:
  - this branch gives up some PF versus the conservative short-only baseline,
  - but it materially improves actual MT5 turnover and total net profit on the shared test window,
  - treat it as the current `higher-turnover candidate`, not as the already-approved live baseline.

## Rejected Variant

- Dual-short expansion:
  - validator looked better, but MT5 report quality degraded
  - experiment note: `knowledge/experiments/2026-03-30-btcusd-session-meanrev-dualshort.md`
  - MT5 run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-30-224908-390620-btcusd-20260330-session-meanrev-.json`
  - result: `335` trades, `PF 1.29`, `net +106.36`
- Spread-loosened MT5 report probe (`max_spread_pips=3000`):
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-30-221315-673455-btcusd-20260330-session-meanrev-.json`
  - result: `132` trades, `PF 1.39`, `net +65.24`
- Spread-loosened probe (`max_spread_pips=3500`):
  - `reports/telemetry/2026-03-30-btcusd-session-meanrev-spread3500.json`
  - `knowledge/experiments/2026-03-30-btcusd-session-meanrev-spread3500.md`
- Result:
  - `3000`: lower net and lower PF than the baseline
  - `3500`: `547` exits, `PF 1.2721`, `3.1437` entries/day
- Decision:
  - do not promote the dual-short expansion,
  - do not promote the wider spread gate at `3000` or `3500`,
  - the added activity came with materially weaker trade quality and far more trade-cap / loss-lock events,
  - the next live-readiness work should focus on session timing or entry construction rather than paying wider spread.

## Review Cadence

- Weekly:
  - check realized spread/slippage vs assumptions,
  - check trade/day drift and rule-trigger counts.
- Quarterly:
  - rerun long-window validation and compare with prior quarter snapshot,
  - retune only if robustness improves on both train/test windows.
