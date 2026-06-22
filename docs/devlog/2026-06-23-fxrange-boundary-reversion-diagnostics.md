# 2026-06-23 - FX Range Boundary Reversion Diagnostics

## Summary

- Task: build one dedicated multi-currency FX range-boundary reversion EA and test 2025 shallow diagnostics.
- EA: `ExpectedValue_MultiCurrency_FXRangeBoundaryReversion`
- Scope: MT5 backtest only. No demo, live, operator, heartbeat, or deployment work.
- Result: implemented, compiled, and tested, but rejected at 2025 shallow gate.

## Changes

- Added `mql/Experts/ExpectedValue_MultiCurrency_FXRangeBoundaryReversion.mq5`.
- Added four scenario presets and tester configs:
  - fixed-R;
  - range-mid target;
  - range-mid target with stronger trend filter;
  - range-mid target with stricter boundary-only zone.
- Added `scripts/analyze-fxrange-boundary-diagnostics.ps1`.
- Archived MT5 reports, EA CSV logs, presets, tester configs, and comparison CSVs under `reports/backtest/runs/`.

## Validation

- Compile command:
  - `powershell -ExecutionPolicy Bypass -File scripts\compile.ps1 -MetaEditorPath "C:\Program Files\XMTrading MT5\MetaEditor64.exe" -Source mql\Experts\ExpectedValue_MultiCurrency_FXRangeBoundaryReversion.mq5 -LogPath reports\compile\ExpectedValue_MultiCurrency_FXRangeBoundaryReversion_compile.txt`
- Compile result: 0 errors, 0 warnings.
- Backtest runner: `scripts/backtest.ps1`
- Terminal path: `C:\Program Files\XMTrading MT5\terminal64.exe`
- Test window: 2025-01-01 to 2025-12-31
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`

## Results

See [summary](../../reports/backtest/runs/20260623_fxrange_boundary_diagnostics/summary.md) and [comparison CSV](../../reports/backtest/runs/20260623_fxrange_boundary_diagnostics/comparison.csv).

| Scenario | Trades | PF | Avg R | Decision |
| --- | ---: | ---: | ---: | --- |
| previous_range_reversion | 494 | 0.88 | -0.0642 | Reject reference |
| fixedR | 500 | 0.79 | -0.1056 | Reject |
| to_mid | 298 | 0.73 | -0.1506 | Reject |
| to_mid_trend_filter | 318 | 0.76 | -0.1363 | Reject |
| to_mid_boundary_only | 203 | 0.62 | -0.2657 | Reject |

## Decision

No scenario reached PF >= 1.05, avg R > 0, and net > 0. Therefore no 3-year fixed BT or recent 12-month OOS was run.

Do not repair this candidate with symbol exclusions, direction-only promotion, Friday stops, or additional narrow filters. Boundary detection worked, but the edge did not.

## Evidence

- [Diagnostics summary](../../reports/backtest/runs/20260623_fxrange_boundary_diagnostics/summary.md)
- [Comparison CSV](../../reports/backtest/runs/20260623_fxrange_boundary_diagnostics/comparison.csv)
- [Range position breakdown](../../reports/backtest/runs/20260623_fxrange_boundary_diagnostics/range_position_breakdown.csv)
- [Failure type breakdown](../../reports/backtest/runs/20260623_fxrange_boundary_diagnostics/failure_type_breakdown.csv)
- [Compile log](../../reports/backtest/runs/20260623_fxrange_boundary_diagnostics/compile.log)

## Next

Keep the diagnostic labels for future research, but park this strategy thesis. The next candidate should not be another boundary-threshold repair of this family.
