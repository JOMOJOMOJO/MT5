# Step 15F GREEN evidence

- Full deterministic suite: PASS 312 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 9 / BLOCKED 0.
- New Step 15F contracts: PASS 36 / FAIL 0.
- Existing pre-Step-15F deterministic contracts retained: PASS 276.
- Remaining SKIP 9 are unchanged terminal-only observations.
- Existing 16 Tick-shock compile targets plus the new context-feature harness: 0 errors / 0 warnings.
- Expected CSV values remain the preregistered independent oracle; the harness calls `TickShockContextFeatures.mqh` production functions.
- Independent-oracle differences: 0.
- Actual order send calls: 0.

Evidence is in `raw/context_feature.csv`, `suite_results.csv`, `step15f_green_results.csv`, `compile_results.csv`, and `independent_oracle.csv`.
