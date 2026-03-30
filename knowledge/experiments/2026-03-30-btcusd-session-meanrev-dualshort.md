# BTCUSD Session Mean-Reversion: Dual-Short Probe

- Date: 2026-03-30
- EA: `btcusd_20260330_session_meanrev`
- Goal: add a second NY-session short bucket without lowering live quality below the current baseline

## Skill-Guided Hypothesis

- `statistical-edge-research` suggested that a second short bucket in the NY session had positive expectancy.
- `strategy-critic` requires rejecting the idea if the extra bucket only raises trade count while degrading MT5 report quality.
- `systematic-ea-trader` requires comparing the new bucket under spread, slippage, drawdown, and trade-count constraints.

## Candidate

- Primary short bucket:
  - `00:00-08:00`
  - `dist=0.87`
  - `max_dist=3.0`
  - `min_atr_pct=0.0003`
  - `rsi=64-82`
- Secondary short bucket:
  - `13:00-22:00`
  - `dist=0.80`
  - `rsi=60-100`
  - `bear trend required` via `EMA20 < EMA50`
- Shared exits / guards:
  - `hold=14`
  - `exit_buffer_atr=0.30`
  - `stop_atr=4.0`
  - `max_spread=2500`
  - `daily_loss_cap=3%`
  - `max_trades_per_day=10`
  - `max_consecutive_losses=5`
  - `cooldown_bars=24`

## Validator Result

- File:
  - `reports/research/2026-03-30-session-meanrev-validate`
- Summary:
  - primary only: `4.80 trades/day`, `PF 1.20`
  - primary + second short: `6.24 trades/day`, `PF 1.30`
- Interpretation:
  - the extra bucket looked attractive in the friction-aware validator.

## MT5 Report Result

- Baseline report-backed run:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-30-212224-417653-btcusd-20260330-session-meanrev-.json`
  - `242 trades`, `PF 1.75`, `net +156.61`
- Dual-short report-backed run:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-30-224908-390620-btcusd-20260330-session-meanrev-.json`
  - `335 trades`, `PF 1.29`, `net +106.36`

## Decision

- Do not promote the dual-short preset to the repo baseline.
- Keep the dual-short capability in code for future reuse.
- Current best live candidate remains the original short-only baseline.

## Why It Was Rejected

- Trade count improved materially.
- MT5 profit factor fell from `1.75` to `1.29`.
- Net profit fell from `+156.61` to `+106.36`.
- Drawdown rose from `0.33%` to `0.55%`.

## Next Step

- Stop widening this family by adding more short buckets.
- Next improvement should target a different logic bucket or a more selective session construction, not just more signal volume.
