# 2026-03-31 BTCUSD Session Pair RR Baseline Reject

- EA: `btcusd_20260331_session_pair_rr`
- Status: `rejected baseline`
- Skills used:
  - `research-director`
  - `statistical-edge-research`
  - `systematic-ea-trader`
  - `risk-manager`
  - `strategy-critic`

## Objective

- Test whether a fresh `R`-based, compounding-aware session pair could replace the parked `session_meanrev` family as the repo mainline.

## Actual MT5 Results

- Pair baseline:
  - run: `reports/backtest/runs/btcusd-20260331-session-pair-rr/btcusd/m5/2026-03-31-121228-746260-btcusd-20260331-session-pair-rr-.json`
  - `net -1166.27`
  - `PF 0.71`
  - `193 trades`
  - `max DD 11.98%`
- Long-only split:
  - run: `reports/backtest/runs/btcusd-20260331-session-pair-rr/btcusd/m5/2026-03-31-121420-336450-btcusd-20260331-session-pair-rr-.json`
  - `net -265.67`
  - `PF 0.96`
  - `315 trades`
  - `max DD 5.52%`
- Short-only split:
  - run: `reports/backtest/runs/btcusd-20260331-session-pair-rr/btcusd/m5/2026-03-31-121504-957421-btcusd-20260331-session-pair-rr-.json`
  - `net -1189.59`
  - `PF 0.52`
  - `107 trades`
  - `max DD 11.99%`

## Interpretation

- The capital doctrine was worth keeping.
- The initial entry construction was not.
- Explicit `R` multiples did not rescue a weak entry mask.
- The least bad branch was `long-only`, but `PF 0.96` is still below the line.

## Decision

- Reject the first `session_pair_rr` baseline.
- Keep the family open only as a research shell.
- Start the next cycle from fresh bar-data mining and new entry masks instead of minor RR retuning.

## Reusable Lesson

- Changing exits and sizing is not enough when the entry mask itself is weak.
- If `pair`, `long-only`, and `short-only` all fail on the first actual window, do not keep polishing the same mask. Go back to chart-pattern mining.
