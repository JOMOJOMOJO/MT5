# 2026-03-31 BTCUSD Session Mean-Reversion Live035 Promotion

- EA: `btcusd_20260330_session_meanrev`
- Status: `live-track candidate`
- Skills used:
  - `systematic-ea-trader`
  - `risk-manager`
  - `strategy-critic`
  - `backtest-analysis`
  - `forward-live-ops`

## Objective

- Re-check the strongest quality branch under a more realistic live risk budget that still respects the permanent capital doctrine.

## Preset

- `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035.set`

## Actual MT5 Result

- run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-124629-524307-btcusd-20260330-session-meanrev-.json`
- `net +327.98`
- `PF 1.78`
- `88 trades`
- `expected payoff 3.73`
- `max DD 1.56%`

## Decision

- Promote this preset as the current `demo-forward candidate`.
- Keep the rest of the family parked for turnover research.
- Do not call this final live-ready yet, because demo-forward still has to be completed.

## Why

- It keeps the best actual quality inside the repo while moving the sizing closer to the intended live capital doctrine.
- The drawdown stayed within a survivable range even after increasing risk from the tiny research preset.
- The higher-turnover research branch is still weaker than this quality branch in actual MT5.
