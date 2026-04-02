# USDJPY quality12b live hardening

- Date: `2026-04-02`
- Family: `usdjpy_20260402_round_continuation_long`
- Branch: `quality12b`

## Objective

- Convert the best surviving `USDJPY long-only` quality branch into a real `demo-forward candidate`.
- Satisfy the repo's long-window drawdown gate before asking the operator for demo-forward proof.

## Change

- Lower the proving preset risk from `2.0%` to `0.65%`.
- Lower the proving preset micro-cap ceiling from `3.0%` to `2.0%`.
- Lower the first-capital preset to `0.50%` and move it to a fresh staged file, `quality12b_smalllive050`.

## Actual MT5 result

- Guarded train `2025-04-01` to `2025-12-31`:
  - `net +804.29`
  - `PF 1.49`
  - `59 trades`
  - `max DD 2.91%`
- Guarded OOS `2026-01-01` to `2026-04-01`:
  - `net +343.11`
  - `PF 2.13`
  - `9 trades`
  - `max DD 2.49%`
- Small-live train `2025-04-01` to `2025-12-31`:
  - `net +618.94`
  - `PF 1.50`
  - `59 trades`
  - `max DD 2.22%`

## Verdict

- `quality12b_guarded` now clears the long-window drawdown gate and is the active `USDJPY long-only` demo-forward candidate.
- The remaining blockers are:
  - real `demo-forward` evidence,
  - a non-self-check forward gate,
  - live heartbeat freshness.
- `quality12b_smalllive050` is the staged first-capital preset after demo-forward passes.
