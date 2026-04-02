# USDJPY quality12b stack guarded promotion

- Date: `2026-04-02`
- Family: `usdjpy_20260402_round_continuation_long`
- Candidate: `quality12b_stack_guarded`

## Objective

- Lift turnover without breaking the live-track quality floor already established by `quality12b_guarded`.

## Change

- Keep the existing `quality12b` round-continuation bucket.
- Add the surviving `EMA13 / EMA100 continuation` London sidecar as a second long-only bucket.
- Reduce proving risk to `0.30%` so the combined branch can be judged on expectancy, not on avoidable drawdown inflation.

## Actual MT5 result

- Train `2025-04-01` to `2025-12-31`:
  - `net +372.93`
  - `PF 1.21`
  - `125 trades`
  - `max DD 2.80%`
- OOS `2026-01-01` to `2026-03-31`:
  - `net +124.05`
  - `PF 1.82`
  - `19 trades`
  - `max DD 0.38%`

## Verdict

- `quality12b_stack_guarded` is promoted to `demo-forward candidate`.
- It is more aligned with the turnover objective than `quality12b_guarded`, but it still does not reach the stated `20 trades/month` target.
- `quality12b_guarded` remains the quality-first anchor.
- `quality12b_stack_guarded` becomes the turnover-biased sidecar candidate for demo-forward proof.
