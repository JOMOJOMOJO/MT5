# Technical 4m/2m analysis — intake and locked split

Date: 2026-09-10. Request: analyze the user's existing January–June capture.
Input directory: `C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/Common/Files/tstech_candidate_202501to06-2`.
Source reference: `5158de8b56bf58953a005b2440a9b86cd6d4746e`.

## Scope and phases

1. Read-only data/provenance QA. No model fit and no May–June profit aggregation.
2. Subject to acceptable provenance/integrity, train/select using January–April only.
3. Freeze model, features, geometry and threshold; then evaluate May through the actual recorded end.

Do not change production MQL, detector, existing CSVs, or old April results.
The two currently deleted TechnicalFeatures/TechnicalStudy includes remain deleted in the worktree; read Git HEAD for definitions.
No MT5 run, order submission, automatic retraining or EA promotion is authorized by this analysis step.

## Statistical design (not executed during intake)

- Broker-server calendar labels encoded by MQL datetime/time_msc, not asserted UTC instants. Boundary: 2025-05-01 00:00 in the same encoded clock.
- January/February learning -> March inner validation; January–March learning -> April inner validation. Whole market clusters stay together; remove training episodes whose observed exit or full label horizon crosses a validation boundary.
- Three fixed families from the existing analyzer: depth-3 tree, regularized logistic, bounded LightGBM. Existing six RR1 geometries and absolute thresholds only; no holdout-driven extra search.
- Primary hypothetical extra round-trip cost 0.2 pip; Bid/Ask already includes spread. Actual commission is separately observed/unknown, never inferred from old Vantage metadata.
- Select using inner chronological portfolio net R, frequency and stability, not full-training fitted profitability. Require >=200 actual simulated trades in each assessed month, PF>1, positive aggregate net R, positive result after top-five removal, and no single positive day >=35% of positive-day R.
- All currencies combined: at most one pending/position, using the existing recognition-clock portfolio evaluator. No hindsight direction fallback after rejected actions.
- Fixed benchmark actions: LONG, SHORT, continuation, reversal. Do not select the winner using the holdout.
- If no candidate passes development gates, report that result. Never weaken gates to force a candidate.
- May/June is a held-out validation period for this exercise, not automatically pristine OOS: usage by other agents/user needs disclosure.

## Intake exception requiring disposition

The initial summary inspection found `VALIDATION_INVALID`, with 15,097 event pool exhaustions.
The legacy trade-scenario pool and Technical episode pool are different. Do not assert all technical episodes were lost; independently reconcile the episode population and Technical counters.
Nevertheless, do not silently override an explicit run-level fail-closed verdict or call a model result formally validated.
If scope-specific evidence cannot clear the issue, preserve the QA findings and stop before model selection/holdout outcome evaluation. Diagnostic-only analysis of surviving rows would need an explicitly documented limited interpretation.

## Outputs

`reports/analysis/tick_shock/technical_4m2m_codex/`: hashes, QA, month/symbol population, sanitized journal evidence, and intake report. Future fitted-model artifacts belong here only after the gate is resolved.
