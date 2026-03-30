# 2026-03-30 BTCUSD Regime Breakout Redesign

- EA: `btcusd_20260124`
- Focus: `sell breakout` を別設計にし、`buy pullback` と非対称化
- Evidence:
  - `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-124643-957621-btcusd-20260124-week1.json`
  - `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-124643-957621-btcusd-20260124-validation-1m.json`
  - `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-124743-917051-btcusd-20260124-validation-1y.json`
  - `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-124743-917051-btcusd-20260124-oos-3m.json`

## What Changed

- `sell breakout` に `EMA へ戻ってから抜ける` 条件を追加した
- `buy` は pullback 側だけを残し、`sell` は breakout 側だけを残した
- H4 confirm regime を導入し、H1 単独の参加を減らした
- `break-even` と `trail` の開始を後ろへずらし、微益逃げを減らした

## Result

- Week 1:
  - Net: `15.97`
  - PF: `1.48`
  - DD: `0.34%`
  - Trades: `2`
- Validation 1M:
  - Net: `70.38`
  - PF: `3.08`
  - DD: `0.33%`
  - Trades: `4`
- Validation 1Y:
  - Net: `-398.75`
  - PF: `0.48`
  - DD: `4.90%`
  - Trades: `35`
- OOS 3M:
  - Net: `60.01`
  - PF: `1.59`
  - DD: `0.68%`
  - Trades: `7`

## Interpretation

- 2026 の直近 regime には合っている
- 2025 を含む 1 年では edge が不足している
- 改善後は `大損する戦略` ではなくなったが、まだ `常時 live-ready` ではない

## Next Action

- 2025 の負け区間を月別に分解して、どの regime で崩れるかを切る
- `buy pullback` をさらに分離するか、2025 では無効化する条件を作る
- short optimization は `breakout buffer`, `confirm multipliers`, `signal body`, `break-even/trail` に限定する
