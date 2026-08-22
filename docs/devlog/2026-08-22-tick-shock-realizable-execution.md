# Tick-shock realizable execution clocks

## Task

Separate ideal event-time research from the time at which the current multi-symbol EA can actually recognize and fill a signal. Remove grid-quote fills, prevent pre-processing entry, correct reversal clocks, and make order-harness observations truthful without changing shock thresholds or starting long OOS.

## Implementation

- Added a shared research execution core with explicit `IDEAL_EVENT_STUDY` and `REALIZABLE_EA` modes, immutable signal clocks, eligibility calculation, next-real-tick entry, market clusters, outward RR rounding, and quote-side broker checks.
- Updated the research EA to arm at detection/invalidation, fill only on a later same-symbol real tick, preserve grid and source-quote clocks, separate symbol/market clusters, and emit audit invariants.
- Corrected 250/500/1,000ms return diagnostics to independent exact anchors.
- Limited sample rings to 3,610/1,806/904 cells for the three detectors and kept tick retention at five seconds or 8,192 cells.
- Reworked the research harness to call shared production functions for 18 deterministic cases.
- Reworked the order harness to track requested/filled/remaining volume and to report unobserved partial fill, restart, and server exits as SKIP rather than PASS.
- Added an independent PowerShell parser that rebuilds all 552 scenario groups and checks execution invariants from `events.csv`.

## Validation

- Three MQL5 programs: 0 errors / 0 warnings.
- Research harness: 18/18 PASS.
- Order harness: 40 observed PASS / 0 FAIL / 4 SKIP / 1 unit-only PASS.
- Final March 2025 real-tick replay: 19 events, 15 market clusters, 350.703-second EA runtime; independent CSV recount fully matches.
- No thresholds, optimization ranges, or test periods were expanded.

Evidence: [run summary](../../reports/backtest/runs/20260822_tickshock_realizable_execution/summary.md), [schema](../research/tick_shock_scalper_csv_schema.md), [QA](../../.company/qa/2026-08-22-tick-shock-realizable-execution.md).
