# BTCUSD Session Mean-Reversion: Live Review Automation

- Date: `2026-03-31`
- Scope: `demo-forward / small-live operator decisions`

## Decision

- Add a mechanical live-review layer on top of telemetry summary, forward gate, and heartbeat status.
- Do not rely on ad hoc operator judgement for the basic `continue / pause / flatten / review` decision.

## Why

- `forward-live-ops` requires explicit promotion and rollback gates.
- `risk-manager` requires hard-loss logic and operator actions that are clear under stress.
- `professional-trader` and `systematic-ea-trader` both reject vague live handling where the operator has to improvise.

## Added Components

- `plugins/mt5-company/scripts/evaluate_live_state.py`
- `scripts/review-live-state.ps1`
- timer-driven status heartbeat in `mql/Experts/btcusd_20260330_session_meanrev.mq5`

## Current Behavior

- Review heartbeat freshness.
- Refresh status heartbeat independently from signal-bar timing.
- Review whether the forward gate is still a self-check.
- Review current spread versus the configured threshold.
- Escalate to `pause` when live soft-block conditions appear.
- Escalate to `flatten` when a hard loss block is active while positions remain open.

## Operating Consequence

- `live-preflight` now also marks stale heartbeat as `review`.
- The repo can now produce a durable live-ops review artifact before the operator touches the command file.
