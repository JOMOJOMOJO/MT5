# BTCUSD Session Mean-Reversion: Launch Manifest

- Date: `2026-03-31`
- Scope: `demo-forward / small-live run lineage`

## Decision

- Persist a launch manifest at the start of every forward or first-capital cycle.

## Why

- Runtime presets are generated dynamically.
- Telemetry file names are generated dynamically.
- Closing the run should not depend on the operator copying the correct filename from console history.

## Added Components

- `scripts/start-demo-forward.ps1`
- `scripts/close-demo-forward.ps1`

## Operating Consequence

- Start scripts now write a manifest JSON and a short note.
- Close scripts can use `-ManifestPath` instead of manual telemetry filename entry.
- Forward and small-live lineage are therefore durable and reproducible.
