# Tick-shock: event time is not executable time

## Reusable finding

A multi-symbol historical merge may preserve event ordering while still replaying a signal after its market timestamp. Any fill model that searches only from `event_time + delay` can then fill before the EA knew the signal. A realizable clock must preserve both event and processing time and use:

`eligible = max(event + requested delay, processing + submit latency)`

The quote must come from the same symbol, be at or after eligibility, and be strictly later than the signal-defining tick. Grid boundaries may arm signals but cannot stand in for a tradable tick.

## Evidence from March 2025

- Detection quote age was 9/107/274ms min/median/max for all 19 events.
- Global merge recognition lag was 412/543/2,388ms.
- Corrected replay produced zero entry-before-processing and zero stale-grid fills.
- In several 0/100/250ms rows the same fill occurred because processing latency dominated the requested delay; this is expected under the max-clock definition.
- Statistical n fell to 15 cross-symbol market clusters even though 7,452 scenario labels were attempted.

## Discipline

Keep event studies and executable-EA studies as explicit modes. Never promote a harness-derived or correlated scenario count as independent trading evidence, and never count unobserved broker behavior as PASS.

Evidence: [March run](../../reports/backtest/runs/20260822_tickshock_realizable_execution/summary.md).
