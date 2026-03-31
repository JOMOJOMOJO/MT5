# 2026-03-31 BTCUSD Session Mean-Reversion Sunday Filter Probe

- EA: `btcusd_20260330_session_meanrev`
- Goal:
  - test whether the surviving long-only branch becomes more live-ready when the weakest weekday is removed,
  - compare shorter hold versus the current `bull15_40 h12` balance candidate,
  - decide whether risk-adjusted quality improves enough to justify a new operations default.
- Skills used:
  - `statistical-edge-research`
  - `research-director`
  - `strategy-critic`
  - `systematic-ea-trader`
  - `risk-manager`
  - `backtest-analysis`

## Research Trigger

- Bar-level analysis on the `bull late long` branch showed that validator-side Sunday entries were the weakest weekday bucket.
- Python follow-up also suggested that `hold=8` could improve the loss profile without killing the branch.
- This was treated as a probe, not a promotion, until actual MT5 reports confirmed it.

## Validator Readout

- `bull15_40_h12_base`
  - all: `172 trades`, `0.62 trades/day`, `PF 1.26`
- `bull15_40_h12_no_sun`
  - all: `152 trades`, `0.55 trades/day`, `PF 1.64`
- `bull15_40_h8_no_sun`
  - all: `155 trades`, `0.56 trades/day`, `PF 1.70`
- `bull15_45_h8_no_sun`
  - all: `166 trades`, `0.60 trades/day`, `PF 1.83`

## Actual MT5 Results

- Existing balance candidate `bull15_40 h12`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-025134-579920-btcusd-20260330-session-meanrev-.json`
  - `net +62.34`
  - `PF 1.42`
  - `139 trades`
  - `max DD 0.48%`

- Sunday-off `bull15_40 h12`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-100523-839703-btcusd-20260330-session-meanrev-.json`
  - `net +55.20`
  - `PF 1.47`
  - `115 trades`
  - `max DD 0.41%`

- Sunday-off `bull15_40 h8`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-100524-135885-btcusd-20260330-session-meanrev-.json`
  - `net +53.75`
  - `PF 1.49`
  - `116 trades`
  - `max DD 0.37%`

- Sunday-off `bull15_45 h8`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-100523-866962-btcusd-20260330-session-meanrev-.json`
  - `net +50.81`
  - `PF 1.38`
  - `142 trades`
  - `max DD 0.40%`

- Conservative quality reference `bull37 h12`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-024622-395041-btcusd-20260330-session-meanrev-.json`
  - `net +68.89`
  - `PF 1.76`
  - `88 trades`
  - `max DD 0.38%`

## Decision

- Reject `bull15_45 h8 no_sun` as a promotion candidate.
- Reject `bull15_40 h12 no_sun` as a strict improvement over the existing `bull15_40 h12` candidate.
- Promote `bull15_40 h8 no_sun` as the current `operations live-candidate`.
- Keep `bull15_40 h12` as the `turnover reference`.
- Keep `bull37 h12` as the `quality reference`.

## Why

- Actual MT5 did not confirm the very large validator uplift from the Sunday filter; the improvement was smaller in reality.
- Even so, `bull15_40 h8 no_sun` improved the practical live-risk profile versus `bull15_40 h12`:
  - higher `PF`
  - lower `max DD`
  - smaller average loss
  - still over `100` trades on the 1-year actual window
- `bull15_45 h8 no_sun` added activity, but quality weakened too much.
- `bull37 h12` still remains the cleanest quality line, but `bull15_40 h8 no_sun` is the better compromise if the objective is live deployment with some turnover.

## Reusable Lesson

- Weekday filters found in Python should not be promoted until actual MT5 confirms them.
- A weekday restriction can still be useful even when it reduces net profit, if the actual branch meaningfully improves `PF`, `drawdown`, and average-loss control.
- For this family, `hold` is part of the risk design, not just a cosmetic timing parameter.

## Next Step

1. Use `bull15_40 h8 no_sun` for demo-forward telemetry.
2. Compare its realized blocked-entry mix and losing-streak behavior against the older `bull15_40 h12` run after the first week.
3. Keep searching for a second long-only bucket or a regime filter that lifts frequency without reopening the weak short side.
