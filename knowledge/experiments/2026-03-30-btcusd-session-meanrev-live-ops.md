# BTCUSD Session Mean-Reversion: Live Operations Playbook

- Date: 2026-03-30
- EA: `btcusd_20260330_session_meanrev`
- Scope: `BTCUSD / M5 / long-only current front`

## Current Candidate

- Preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull15_40_long_h8_no_sun.set`
- Strategy shape:
  - `bull-filtered late-session long only`
  - `long_dist=1.50`
  - `long_rsi_max=40`
  - `hold_bars=8`
  - `weekdays=1,2,3,4,6`
- Current MT5 result:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-100524-135885-btcusd-20260330-session-meanrev-.json`
  - `net +53.75`
  - `PF 1.49`
  - `116` trades
  - `max DD 0.37%`
- Status:
  - treat this as the current `operations live-candidate`,
  - keep `bull15_40 h12` as the turnover reference,
  - keep `bull37 long-only` as the conservative quality reference,
  - do not promote any mixed-direction or short-side branch from this family right now.

## Conservative Reference

- Preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12.set`
- Current MT5 result:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-024622-395041-btcusd-20260330-session-meanrev-.json`
  - `net +68.89`
  - `PF 1.76`
  - `88` trades
  - `max DD 0.38%`
- Interpretation:
  - lower turnover than the current candidate,
  - but still the highest-quality actual result inside the current family.

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

## Direction Split Result

- direction-split note:
  - `knowledge/experiments/2026-03-31-btcusd-session-meanrev-direction-split.md`
- actual decision:
  - mixed-direction variants failed on the 1-year actual MT5 window,
  - short-only `asia100` also failed,
  - only the long side survived.
- operating consequence:
  - do not deploy this family as a mixed-direction EA,
  - if the short side is revisited later, treat it as a separate research branch and require its own actual-first promotion path.

## Long-Only Expansion

- long-only refinement note:
  - `knowledge/experiments/2026-03-31-btcusd-session-meanrev-direction-split.md`
- Sunday filter probe:
  - `knowledge/experiments/2026-03-31-btcusd-session-meanrev-sunday-filter-probe.md`
- second long bucket probe:
  - `knowledge/experiments/2026-03-31-btcusd-session-meanrev-second-long-bucket-probe.md`
- tested long-only variants:
  - `bull37`: best quality
  - `bull15_40 h12`: best turnover among the surviving actual candidates
  - `bull15_40 h8 no_sun`: better live-risk profile than `bull15_40 h12`
  - `bull12_45`: turnover gain was too expensive in PF
- current choice:
  - `bull15_40 h8 no_sun` for the operations live candidate,
  - `bull15_40 h12` as the turnover reference,
  - `bull37 long-only` as the fallback quality reference.
  - `bull15_40 h8 no_sun_no_tue` was tested and rejected after actual MT5.
  - `NY second long bucket` was rejected at validator stage before actual MT5.

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
  - do not promote mixed-direction long/short combinations from this family on the current same-symbol deployment path,
  - the added activity came with materially weaker trade quality and far more trade-cap / loss-lock events,
  - the next live-readiness work should focus on long-only forward behavior and actual-first expansion of the surviving long bucket.

## Review Cadence

- Weekly:
  - check realized spread/slippage vs assumptions,
  - check trade/day drift and rule-trigger counts.
- Quarterly:
  - rerun long-window validation and compare with prior quarter snapshot,
  - retune only if robustness improves on both train/test windows.
