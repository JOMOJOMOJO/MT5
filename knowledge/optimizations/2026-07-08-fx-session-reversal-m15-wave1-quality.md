# FX Session Reversal M15 Wave1 Quality Outcome

## Hypothesis

`M15 wave2 required-light` is a profitable but too-small fragment. Instead of loosening wave2 conditions, test whether the preceding M15 wave1 quality separates candidates that can launch a real M15 third wave.

Wave1 quality was measured only with pre-entry closed bars:

- impulse size in ATR
- body efficiency
- break quality
- overlap/chop
- speed and age
- follow-through before wave2
- obstacle clearance

MFE and result labels were used only in analysis, never in entry logic.

## Full 2025 Outcome

| Candidate | Trades | PF | avg_R | Net | avg_MFE |
| --- | ---: | ---: | ---: | ---: | ---: |
| baseline c10 | 318 | 0.59 | -0.1582 | -1144.89 | 0.597R |
| required-light | 50 | 1.34 | +0.1099 | +134.29 | 0.781R |
| required-light AND wave1 quality | 7 | 0.39 | -0.2733 | -48.65 | 0.710R |
| required-light OR wave1 quality | 87 | 0.82 | -0.0701 | -144.12 | 0.673R |
| wave1 quality only | 51 | 0.46 | -0.2164 | -262.10 | 0.585R |
| required-light OR wave1 quality + corrective exhaustion | 67 | 1.08 | +0.0274 | +44.15 | 0.701R |
| one-symbol required-light wave1 diagnostic | 35 | 1.74 | +0.2133 | +183.93 | 0.800R |

## Lessons

- Wave1 quality alone does not have standalone edge in this implementation.
- AND with required-light overfilters and worsens the small high-quality fragment.
- OR with required-light expands from 50 to 87 trades but loses expectancy.
- Adding corrective exhaustion to the OR form creates a small positive fragment, but only 67 trades.
- One-symbol improvement is not promotion evidence because it remains small and concentrated.
- The original required-light 50-trade fragment remains the best all-symbol quality slice, but it is too sparse for operation.

## Decision

No 2025 shallow gate pass. Do not run 3-year fixed BT or OOS for this cycle.

Further work should not tune these wave1 thresholds narrowly. The next useful experiment needs a structurally different separator or a different strategy family, not another small threshold adjustment around wave1 quality.

## Evidence

- `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/summary.md`
- `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/full2025_comparison.csv`
- `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/mfe_by_m15_wave1_quality.csv`
- `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/wave1_quality_x_corrective_exhaustion_breakdown.csv`
