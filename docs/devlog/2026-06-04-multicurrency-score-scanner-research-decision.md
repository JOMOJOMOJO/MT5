# 2026-06-04 - Multi-Currency Scanner Research Decision

## Summary

- Task: consolidate Phase2, OOS, ThirdWave, regime, scan interval, All Candidates, Wave Audit, and ThirdWave v2 evidence before starting another implementation cycle.
- Scope: reporting only. No EA logic, parameters, or tester configs were changed.

## Evidence

- Master comparison: `reports/backtest/research_master_comparison.csv`
- Failure matrix: `reports/backtest/failure_cause_matrix.csv`
- Decision report: `reports/backtest/research_decision_report.md`
- Candidate list: `reports/backtest/next_phase_candidates.md`
- Recommended task: `reports/backtest/recommended_next_task.md`

## Decision

- Do not promote the current Phase2 or ThirdWave branches.
- Do not optimize parameters yet.
- Treat Phase2 2025 LONG strength as OOS-weak and XAUUSD-influenced.
- Treat ThirdWave v2 as diagnostic, not validated, because its annual gate did not pass.
- The next research task should target ThirdWave entry timing and wave-position quality, not regime, SL/TP, or candidate ranking first.

## Rationale

- Wave Audit showed current ThirdWave is mostly `chasing_entry`, not clean third-wave initial entry.
- Regime filtering improves some years but does not solve 2025.
- All Candidates and scan interval comparisons did not reveal a broad multi-symbol edge.
- 15m scan improvement is likely trade-count reduction, not a stable edge.
