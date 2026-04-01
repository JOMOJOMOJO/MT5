# Live-Ready Definition

- Date: `2026-04-01`
- Scope: repo-wide definition of what counts as ready for demo, small-live, and live discussion

## Status Ladder

- `research`
  - hypothesis stage
- `serious validation`
  - actual MT5 evidence exists
- `demo-forward candidate`
  - actual MT5 quality is good enough to justify real-time proving
- `small-live staged`
  - demo-forward proving preset passed
  - reduced-risk preset prepared
- `live-discussion ready`
  - enough evidence exists to talk about first capital seriously

## Mandatory Gates

- Compile:
  - clean compile
- Long-window actual MT5:
  - positive net
  - `PF >= 1.30`
  - survivable drawdown
  - sample size informative enough for the claimed style
- Latest available 3-month OOS actual MT5:
  - explicit dates recorded
  - positive net
  - `PF >= 1.20`
  - no obvious regime break versus the long-window baseline
- Demo-forward:
  - at least one reviewed real demo-forward cycle
  - no unexpected rule violations
  - spread and slippage not materially worse than the tested assumptions
- First capital:
  - reduced-risk preset
  - staged preflight
  - clear rollback route

## Micro-Capital Gate

- If the intended starting capital is around `100 USD`, the candidate must also pass lot-floor viability.
- That means:
  - broker minimum lot size does not force materially more risk than intended,
  - or the broker offers a cent / micro contract structure that restores fine sizing.
- If the symbol cannot express sane risk on `100 USD`, the candidate is not micro-cap deployable even if the strategy logic is good.

## Practical Meaning

- `Good backtest` is not enough.
- `Good demo-forward` is not enough if the lot floor forces oversized risk.
- `High PF with too few trades` can still be useful, but it should be labeled as a quality-first secondary candidate, not automatically treated as the mainline compounding engine.
