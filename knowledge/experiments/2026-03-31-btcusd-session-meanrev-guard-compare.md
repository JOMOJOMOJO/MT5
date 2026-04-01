# 2026-03-31 BTCUSD Session Mean-Reversion Guard Compare

- EA: `btcusd_20260330_session_meanrev`
- Objective:
  - compare how much live-style protection can be added before the quality branch becomes too degraded for deployment.
- Skills used:
  - `risk-manager`
  - `strategy-critic`
  - `backtest-analysis`
  - `forward-live-ops`

## Compared Presets

- `bull37_long_h12_live035`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-124629-524307-btcusd-20260330-session-meanrev-.json`
  - `net +327.98`
  - `PF 1.78`
  - `88 trades`
  - `max DD 1.56%`
- `bull37_long_h12_live035_guarded`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-125152-147086-btcusd-20260330-session-meanrev-.json`
  - `net +68.11`
  - `PF 1.24`
  - `49 trades`
  - `max DD 1.07%`
- `bull37_long_h12_live035_guarded2`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-125328-286235-btcusd-20260330-session-meanrev-.json`
  - `net +177.86`
  - `PF 1.49`
  - `70 trades`
  - `max DD 1.58%`

## What Changed

- `guarded`:
  - `max_open=1`
  - `max_per_side=1`
  - equity-based daily loss cap
  - protective flatten on daily cap and equity cap
  - `max_trades_per_day=4`
- `guarded2`:
  - `max_open=2`
  - `max_per_side=2`
  - equity-based daily loss cap
  - protective flatten on daily cap and equity cap
  - `max_trades_per_day=20`

## Decision

- Reject `guarded` as too restrictive.
- Promote `guarded2` as the current `demo-forward candidate`.
- Keep the less-guarded `live035` result as the upside reference, not as the first deployment preset.

## Why

- `guarded2` preserves enough of the original edge while adding explicit live-style protection.
- `guarded` cut turnover and expectancy too much.
- For first deployment, the company should prefer a slightly weaker but more controlled profile.
