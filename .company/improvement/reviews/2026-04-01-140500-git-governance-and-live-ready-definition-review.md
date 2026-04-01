# Improvement Review

- Date: `2026-04-01`
- Topic: `git governance and live-ready definition`

## Why

- The repo needed a stable branch strategy so Codex can manage git end-to-end.
- The repo also needed a reusable record of how the current EA improved, so future work does not restart from vague intuition.
- The live-ready definition needed an explicit micro-capital check because the intended first capital is around `100 USD`.

## Changes

- added `.company/git/branch-strategy.md`
- added git helper scripts
- added `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`
- added `knowledge/patterns/2026-04-01-live-ready-definition.md`
- added micro-cap risk-floor checks to company doctrine and QA / release gates
- added an EA-side lot-floor risk guard

## Expected Effect

- cleaner branches
- clearer commit / push cadence
- less accidental promotion of candidates that cannot size safely on small capital
- faster reuse of the actual improvement cycle that worked in this repo
