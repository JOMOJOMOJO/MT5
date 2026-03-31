# 2026-03-31 BTCUSD Session Mean-Reversion Tuesday Filter Probe

- EA: `btcusd_20260330_session_meanrev`
- Goal:
  - test whether removing the weak Tuesday bucket on top of `bull15_40 h8 no_sun` improves actual MT5 quality enough to justify promotion,
  - keep only one current operations candidate for demo-forward.
- Skills used:
  - `statistical-edge-research`
  - `research-director`
  - `strategy-critic`
  - `systematic-ea-trader`
  - `risk-manager`
  - `backtest-analysis`

## Validator Readout

- Existing `bull15_40 h8 no_sun`
  - all: `155 trades`, `0.56 trades/day`, `PF 1.70`
- Candidate `bull15_40 h8 no_sun_no_tue`
  - all: `105 trades`, `0.39 trades/day`, `PF 2.20`

## Actual MT5 Result

- Candidate `bull15_40 h8 no_sun_no_tue`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-111157-381169-btcusd-20260330-session-meanrev-.json`
  - `net +38.19`
  - `PF 1.44`
  - `86 trades`
  - `max DD 0.45%`

- Current operations candidate `bull15_40 h8 no_sun`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-100524-135885-btcusd-20260330-session-meanrev-.json`
  - `net +53.75`
  - `PF 1.49`
  - `116 trades`
  - `max DD 0.37%`

## Decision

- Reject `bull15_40 h8 no_sun_no_tue` as a promotion candidate.
- Keep `bull15_40 h8 no_sun` as the current operations live-candidate.

## Why

- Actual MT5 did not confirm the validator-side uplift.
- The Tuesday filter cut too much activity while failing to improve the real drawdown profile.
- Compared with the current operations candidate, it delivered:
  - lower `net`
  - lower `PF`
  - fewer `trades`
  - worse `max DD`

## Reusable Lesson

- A weekday bucket that looks weak in Python is not enough by itself; the full actual MT5 execution path can easily invalidate that conclusion.
- When a filter reduces trades materially, it must improve both `PF` and `drawdown` in actual MT5, not just one proxy in Python.

## Next Step

1. Stop adding weekday exclusions to this branch unless a future actual-first probe shows a clear improvement.
2. Search for a second long-only bucket or a broader regime control instead of squeezing the same late-session bucket further.
