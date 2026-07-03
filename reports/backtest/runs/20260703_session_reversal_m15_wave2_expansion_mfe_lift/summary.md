# M15 Wave2 Expansion MFE Lift Validation

## Scope

- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Main file: `mql/Experts/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.mq5`
- Objective: preserve the previous `M15 wave2 required-light` MFE lift while broadening M15 wave2 context enough to recover trade count.
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Test windows: Q1 quick check and 2025 full-year fixed validation.
- Tester period: M15. EA presets explicitly use H1=`16385`, M15=`15`, M5=`5`.
- M5 scan check: all exported trades have `selected_candidate_timeframe=PERIOD_M5`.
- M5 ABC/123 invalidation was not made a hard gate in the main candidate matrix.

## Artifacts

- Compile log: `compile.log`
- Matrix: `run_matrix.csv`
- Main comparison: `full2025_comparison.csv`
- All trades: `trades_all_scenarios.csv`
- Key breakdowns:
  - `m15_wave2_expansion_breakdown.csv`
  - `m15_wave2_gate_breakdown.csv`
  - `m15_wave2_fib_breakdown.csv`
  - `m5_pattern_quality_breakdown.csv`
  - `mfe_threshold_breakdown.csv`
  - `mfe_by_m15_wave2_mode.csv`
  - `mfe_by_m15_wave2_gate_mode.csv`
  - `mfe_by_m5_pattern_quality.csv`
  - `entry_timeframe_breakdown.csv`
  - `exit_type_breakdown.csv`

## Full 2025 Key Rows

| run | trades | PF | avg_R | net | avg_MFE | MFE>=1R | MFE>=1.3R | time exit | TP |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline c10 | 313 | 0.58 | -0.1618 | -1152.02 | 0.598R | 24.6% | 12.5% | 74.1% | 15.3% |
| m15_wave2_required_light | 50 | 1.34 | +0.1099 | +134.29 | 0.781R | 40.0% | 24.0% | 56.0% | 30.0% |
| m15_wave2_required_expanded | 280 | 0.63 | -0.1446 | -924.71 | 0.615R | 26.1% | 14.6% | 72.5% | 16.8% |
| m15_wave1_or_wave2_context | 314 | 0.58 | -0.1637 | -1166.15 | 0.599R | 24.8% | 12.4% | 74.2% | 15.3% |
| m15_not_opposite_plus_pullback | 229 | 0.66 | -0.1293 | -700.03 | 0.650R | 27.9% | 15.7% | 70.7% | 17.9% |
| fib_or_structure_pullback | 281 | 0.63 | -0.1487 | -958.80 | 0.611R | 25.3% | 14.9% | 71.5% | 17.1% |
| low-quality M5 gate | 316 | 0.58 | -0.1644 | -1179.96 | 0.595R | 24.4% | 12.3% | 74.4% | 15.2% |
| medium/low M5 gate | 314 | 0.58 | -0.1628 | -1161.95 | 0.599R | 24.5% | 12.4% | 74.2% | 15.3% |
| one-symbol expanded | 83 | 1.02 | +0.0094 | +15.86 | 0.653R | 30.1% | 21.7% | 66.3% | 25.3% |
| no-session expanded diagnostic | 305 | 0.61 | -0.1461 | -1019.73 | 0.608R | 25.6% | 13.1% | 73.8% | 16.1% |
| expanded fixed TP/SL only | 281 | 0.68 | -0.1675 | -1089.53 | 0.722R | 34.2% | 18.9% | 29.2% | 21.7% |
| expanded shorter hold diagnostic | 283 | 0.71 | -0.0948 | -639.56 | 0.553R | 19.8% | 8.8% | 79.9% | 9.9% |

Small reference fragments:

- Tokyo baseline: 17 trades, PF 2.07, avg_R +0.2464.
- London baseline: 21 trades, PF 1.17, avg_R +0.0646.
- Clean target path baseline: 9 trades, PF 1.68, avg_R +0.1656.
- These are research fragments only. They are far below 200 trades and are not promotion candidates.

## Required Findings

1. Baseline c10 reproduction: approximately reproduced. Prior reference was 318 trades / PF 0.59 / avg_R -0.1582; this run produced 313 trades / PF 0.58 / avg_R -0.1618.
2. `m15_wave2_required_light` reproduction: reproduced exactly enough for validation. It produced 50 trades / PF 1.34 / avg_R +0.1099 / avg_MFE 0.781R.
3. M15 wave2 expansion increased trade count: yes. Expanded modes reached 229-316 trades, compared with 50 trades for required-light.
4. PF / avg_R / MFE preservation: not preserved. Trade-count recovery pulled PF back to 0.58-0.66 and avg_R stayed negative.
5. MFE>=1R improved vs baseline only modestly in broad candidates: baseline 24.6%, expanded 26.1%, not-opposite 27.9%. The required-light 40.0% lift did not survive broadening.
6. MFE>=1.3R improved only modestly in broad candidates: baseline 12.5%, expanded 14.6%, not-opposite 15.7%. Required-light remained much better at 24.0%.
7. Required-light 50 trades could be expanded beyond 200 trades, but not with positive expectancy. The best broad all-symbol candidate by avg_R was not-opposite at 229 trades, PF 0.66, avg_R -0.1293.
8. M5 pattern quality gate was not effective. Low-quality and medium/low gates behaved almost like baseline and did not preserve the required-light lift.
9. One-symbol combination was better but not promotable: 83 trades / PF 1.02 / avg_R +0.0094. It is below 200 trades and is a research fragment only.
10. M5 ABC hard gate was not used to repair the result. M5 ABC remained diagnostic/score in the main matrix.
11. Time exit did not materially improve in broad candidates. Baseline was 74.1%; expanded was 72.5%; not-opposite was 70.7%. Required-light was much better at 56.0%, but only 50 trades.
12. TP rate did not materially improve in broad candidates. Baseline was 15.3%; expanded was 16.8%; not-opposite was 17.9%. Required-light reached 30.0%, but only 50 trades.
13. Results do not depend on Tokyo/London/Clean fragments for the decision. Those fragments were saved but rejected for promotion because of tiny sample size.
14. 2025 shallow gate pass candidates: none.
15. 3-year fixed BT / OOS: not run, because no 2025 full-year candidate passed the shallow gate.

## Exit Notes

- Fixed TP/SL only increased avg_MFE and MFE>=1R, but avg_R remained negative and full SL increased. This suggests the entry population still contains too many poor launches.
- Shorter hold improved avg_R relative to expanded M5 failure exit, but it cut avg_MFE, MFE>=1R, and TP rate. This is not an entry-quality improvement.
- The main failure remains entry selection, not TP/BE/SL tuning.

## MT5 Report Notes

All Q1 and full2025 runs produced EA trade/summary CSV data and were included in `comparison.csv`.
Some full2025 runs did not produce a fresh MT5 HTML report before `scripts/backtest.ps1` timed out its report freshness check. Those runs are still included from EA CSV evidence; HTML report availability is incomplete for this batch.

## Decision

Do not promote any candidate to 3-year fixed BT, OOS, demo, or live.
The previous `M15 wave2 required-light` condition remains a useful research fragment because it separated MFE quality, but the current broadening methods recovered trade count by reintroducing low-expectancy trades.
Do not repair this by excluding symbols, limiting direction, stopping weekdays, tightening M5 ABC, or fine-tuning TP/BE/SL.
