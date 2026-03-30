# BTCUSD baseline must not be promoted from a single good week

- Date: 2026-03-30
- EA: btcusd_20260124
- Symbol: BTCUSD
- Timeframe: M1
- Evidence:
  - reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-105849-778159-btcusd-20260124-week1.json
  - reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-112412-602375-btcusd-20260124-validation-1y.json
  - reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-112445-736238-btcusd-20260124-oos-3m.json

## Summary

A near-break-even week is not enough evidence. The same preset collapsed on both the 1-year validation and the explicit 3-month out-of-sample run.

## Details

- Week sample: PF 0.96, net profit -75.00, DD 7.90%, 33 trades
- 1-year validation: PF 0.53, net profit -9810.97, DD 98.16%, 1165 trades
- 3-month OOS: PF 0.42, net profit -6990.55, DD 70.61%, 259 trades

The correct next action is not parameter polishing. The algorithm or regime handling needs redesign before any live-readiness discussion.
