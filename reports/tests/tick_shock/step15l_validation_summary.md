# Step 15L validation summary

- Research EA compile: 0 errors / 0 warnings (`reports/compile/tick_shock/step15l_research_ea.log`)
- Clean-move feature harness compile: 0 errors / 0 warnings (`reports/compile/tick_shock/step15l_clean_move_feature_harness.log`)
- Clean-move feature harness: 8 PASS / 0 FAIL
- Existing MQL harnesses rerun using phase `step15h`: 403 MATCH / 11 SKIP; 16 compile logs contain 0 errors / 0 warnings
- Existing Python registry rerun using phase `step15g`: 361 PASS / 0 FAIL / 9 SKIP
- Model-pipeline QA: 10 PASS / 0 FAIL
- Independent persisted-output reconciliation: 23 PASS / 0 FAIL
- Deterministic pipeline rerun: 29 generated analysis files compared, SHA changes 0
- Formal research orders/trades: 0 / 0

The runner does not yet expose a `step15l` phase, so the latest supported unchanged-regression phases were used. Their generated Step 15H/15G files were compared and left unchanged after execution. SKIP is not treated as PASS.

Commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_mql_harnesses.ps1 -TimeoutSeconds 45 -Phase step15h
python tools/tick_shock/run_python_tests.py --phase step15g
python tools/tick_shock/analyze_step15l_clean_move.py --step15k reports/analysis/tick_shock/step15k --run-dir reports/backtest/runs/20260903_ts15l_clean_move_ml_r1_202503 --out-dir reports/analysis/tick_shock/step15l
python tools/tick_shock/step15l_independent_oracle.py --analysis-dir reports/analysis/tick_shock/step15l --run-dir reports/backtest/runs/20260903_ts15l_clean_move_ml_r1_202503
```
