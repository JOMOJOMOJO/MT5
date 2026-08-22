# Multi-currency tick-shock baseline verdict (historical)

The original `NO_EDGE_OBSERVED` conclusion was withdrawn because the validation implementation could not support an edge decision. The v4 repair moved the result to `EDGE_UNDETERMINED`, but no broker-feasible shadow outcome survived its policy invalidation.

Reusable lesson: scenario-label count is not sample count. A stop/delay/spread grid over a handful of events must be reported as correlated variants, while event clusters remain the statistical unit.

The current evidence superseding this historical note is [the 2026-08-22 experiment](2026-08-22-tick-shock-execution-revision.md).
