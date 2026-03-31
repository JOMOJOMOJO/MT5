# 2026-03-31 BTCUSD Session Mean-Reversion Second Long Bucket Probe

- EA: `btcusd_20260330_session_meanrev`
- Goal:
  - test whether a second long-only bucket can raise turnover without reopening the failed short side,
  - reject weak additions before spending another actual MT5 cycle.
- Skills used:
  - `statistical-edge-research`
  - `research-director`
  - `strategy-critic`
  - `systematic-ea-trader`
  - `risk-manager`

## Candidate Shape

- Base candidate:
  - `bull15_40 h8 no_sun`
  - late-session long only
- Added bucket under test:
  - `NY bull long`
  - hour window `13:00-22:00`
  - `dist=1.5 ATR`
  - `RSI<=30` or `<=35`
  - shared `hold=8`

## Validator Results

- Base `bull15_40 h8 no_sun`
  - all: `155 trades`
  - `0.56 trades/day`
  - `PF 1.70`

- Base + `NY bull 1.5 / RSI<=30`
  - train: `PF 0.93`
  - test: `PF 1.30`
  - all: `280 trades`
  - `1.01 trades/day`
  - `PF 1.05`

- Base + `NY bull 1.5 / RSI<=35`
  - train: `PF 0.81`
  - test: `PF 1.18`
  - all: `343 trades`
  - `1.23 trades/day`
  - `PF 0.93`

- Base + `NY bull 1.2 / RSI<=35`
  - train: `PF 0.81`
  - test: `PF 1.08`
  - all: `410 trades`
  - `1.47 trades/day`
  - `PF 0.90`

## Decision

- Reject the `NY second long bucket` branch before actual MT5.
- Keep the second-long implementation support in code, but leave it disabled.

## Why

- The added bucket raised turnover, but it broke the train side badly.
- This is exactly the kind of addition that looks attractive because it adds trades, but does not survive robustness discipline.
- `strategy-critic` rule applies here:
  - do not spend an actual MT5 cycle on a bucket that already fails the long-window train slice.

## Reusable Lesson

- For this family, the surviving long edge is concentrated in the late-session mean-reversion setup.
- A second long bucket must improve turnover without taking train PF below `1.0`.
- If a candidate only works in the recent test slice, treat it as regime drift or data-snooping risk until proven otherwise.

## Next Step

1. Stop trying to add another discretionary-looking long bucket on time-of-day alone.
2. Search for a regime control that protects the existing late-session edge instead.
3. Keep demo-forward work focused on the current operations candidate.
