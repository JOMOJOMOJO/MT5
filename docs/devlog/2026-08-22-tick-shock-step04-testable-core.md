# Tick-shock Step 4: testable production core extraction

The research EA was split into explicit domain/config/result modules and an MT5
adapter without changing strategy or execution behavior. The stable root include
paths remain compatibility facades, so both existing harnesses continue to
compile unchanged.

Evidence:

- architecture: [`../research/tick_shock/04_to_be_architecture.md`](../research/tick_shock/04_to_be_architecture.md)
- module wiring: [`../research/tick_shock/04_module_mapping.md`](../research/tick_shock/04_module_mapping.md)
- comparison report: [`../../reports/refactor/tick_shock/step04_refactor_report.md`](../../reports/refactor/tick_shock/step04_refactor_report.md)
- machine comparison: [`../../reports/refactor/tick_shock/step04_behavior_comparison.csv`](../../reports/refactor/tick_shock/step04_behavior_comparison.csv)

The 2025-03 preservation run compared 272,155 values across CSV schema, event identity,
detector, state, signal, scenario execution, policy, cluster, and funnel fields.
There were zero unintended differences against the manifest-registered run that
matches the immediate pre-refactor source. The older mandatory baseline has 54
explicit `REFERENCE_VERSION_DRIFT` rows because it predates the current causal
execution revision.

All ten new includes were compiled through the research EA; the research and
order harnesses were compiled through the compatibility wrappers. Each target
reported 0 errors and 0 warnings. No Step 3 fixture or expected file changed.

This is a testability refactor, not `EXECUTION_MODEL_VALIDATED`. Known defects,
long OOS, parameter optimization, and promotion to a trading EA remain out of
scope until Step 5 production-path tests exist.
