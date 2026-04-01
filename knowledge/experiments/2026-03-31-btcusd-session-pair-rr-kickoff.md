# 2026-03-31 BTCUSD Session Pair RR Kickoff

- EA: `btcusd_20260331_session_pair_rr`
- Status: `mainline kickoff, first baseline rejected`
- Objective:
  - replace the parked `session_meanrev` family as the mainline research branch,
  - move to an explicit `R`-based risk and reward model,
  - pursue a higher-turnover BTCUSD intraday system without breaking the new capital doctrine.
- Skills used:
  - `research-director`
  - `statistical-edge-research`
  - `systematic-ea-trader`
  - `risk-manager`
  - `strategy-critic`

## Doctrine

- `knowledge/patterns/2026-03-31-expectancy-compounding-doctrine.md`
- `knowledge/patterns/2026-03-31-ea-research-reuse-rules.md`

## Source Research

- `reports/research/2026-03-31-btcusd-m5-edge-refresh/summary.md`
- `reports/research/2026-03-31-session-candidate-sweep/summary.md`

## Starting Hypothesis

- Use one long bucket and one short bucket that were strong enough in bar-data mining to justify fresh actual-first testing.
- Convert them into a new family with:
  - explicit stop placement,
  - explicit reward multiple,
  - equity-based compounding,
  - hard daily loss cap and equity kill-switch.

## Baseline Buckets

- Long:
  - late session `20:00-24:00`
  - `dist <= -1.2 ATR`
  - `RSI <= 35`
  - no trend filter
  - `hold = 12 bars`
- Short:
  - NY session `13:00-22:00`
  - `dist >= +0.6 ATR`
  - `RSI >= 60`
  - bear trend required
  - `hold = 12 bars`

## Baseline Risk Model

- Per-trade risk: `0.35%` of current equity
- Daily hard-loss cap: `3.0%`
- Peak-to-valley kill-switch: `12.0%`
- Stop distance: `1.0 ATR`
- Reward target: `1.35R`
- Daily trade cap: `12`

## Why This Is A New Family

- The parked `session_meanrev` family optimized around mean reversion to EMA exits.
- This family is explicitly built around expectancy and `R` multiples from the start.
- The goal is not to rescue the old family. The goal is to open a cleaner branch that matches the permanent charter.

## Immediate Next Step

1. Re-mine the entry zones before retuning the same pair.
2. Keep the capital doctrine fixed while searching for a better entry construction.
3. Require actual MT5 proof before changing status from `research` to `candidate`.

## First Actual Result

- Pair baseline:
  - `reports/backtest/runs/btcusd-20260331-session-pair-rr/btcusd/m5/2026-03-31-121228-746260-btcusd-20260331-session-pair-rr-.json`
  - `net -1166.27`
  - `PF 0.71`
  - `193 trades`
  - `max DD 11.98%`
- Long-only split:
  - `reports/backtest/runs/btcusd-20260331-session-pair-rr/btcusd/m5/2026-03-31-121420-336450-btcusd-20260331-session-pair-rr-.json`
  - `net -265.67`
  - `PF 0.96`
  - `315 trades`
  - `max DD 5.52%`
- Short-only split:
  - `reports/backtest/runs/btcusd-20260331-session-pair-rr/btcusd/m5/2026-03-31-121504-957421-btcusd-20260331-session-pair-rr-.json`
  - `net -1189.59`
  - `PF 0.52`
  - `107 trades`
  - `max DD 11.99%`

## Decision

- Keep the family as the current research branch.
- Reject the first baseline entry construction.
- Do not spend the next cycle on RR tweaks alone.
- The next cycle must start from new chart-pattern mining and new entry masks.
