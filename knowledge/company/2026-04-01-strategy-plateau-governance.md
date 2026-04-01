# Strategy Plateau Governance

- Date: `2026-04-01`
- Purpose: stop overstaying inside one EA family when the family keeps missing the active business objective

## Decision

- The repo now runs a plateau review after each serious cycle.
- Plateau review is a required artifact once a family has:
  - gone through three serious cycles,
  - or kept missing the active objective,
  - or shown no meaningful improvement in both actual MT5 and recent OOS.

## Expected Behavior

- If the family is quality-positive but objective-negative:
  - keep it as `secondary` or `parked`
  - preserve its knowledge
  - open a new family immediately
- If the family is no longer quality-positive:
  - kill it
  - keep only the lessons

## Why This Matters

- AI makes trial cheap, so the bottleneck is no longer idea generation.
- The real bottleneck is stopping weak structure fast enough.
- The company should optimize for:
  - fast experiments,
  - clean knowledge capture,
  - rapid family replacement when the business objective is being missed.

## Current Application

- `btcusd_20260330_session_meanrev` stays useful as a quality-first secondary family.
- It is not the right mainline for a high-turnover compounding objective.
- Plateau review exists so this judgement becomes reusable process instead of one-off chat logic.
