# BTCUSD Session Mean-Reversion: Small-Live Launch Guard

- Date: `2026-03-31`
- Scope: `first-capital launch control`

## Decision

- Add a dedicated wrapper so the first-capital launch does not rely on the operator remembering to run preflight manually.
- Add a dedicated action wrapper so operator-mode changes are left as durable artifacts rather than terminal-only actions.

## Added Components

- `scripts/start-small-live.ps1`
- `scripts/act-on-live-review.ps1`

## Operating Consequence

- `start-small-live.ps1` blocks launch when `small-live-preflight` returns `fail`.
- It also blocks `review` by default, unless the operator explicitly opts in with `-AllowReview`.
- `act-on-live-review.ps1` records the latest live review result and only auto-applies `pause` or `flatten` when those are the recommended actions.
