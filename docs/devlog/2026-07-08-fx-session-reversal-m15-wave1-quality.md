# FX Session Reversal M15 Wave1 Quality Diagnostics

## Task

Test `M15 wave1 quality` as a new separator for `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`.

The aim was not to loosen `M15 wave2 required-light` further. The hypothesis was that a later M15 third-wave launch depends on whether the preceding M15 wave1 was a real impulse: enough ATR distance, body efficiency, clean break, low chop, acceptable age, hold after wave1, and room to the next obstacle.

## Code Changes

- Added `InpUseM15Wave1Quality`.
- Added `InpM15Wave1QualityMode`: off, diagnostic_only, score, required_light, required_strict.
- Added `InpM15Wave1QualityCombineMode` for the fixed comparison runs:
  - independent
  - required-light AND wave1 quality
  - required-light OR wave1 quality
  - required-light OR wave1 quality plus corrective exhaustion
- Added pre-entry M15 wave1 diagnostics to signal/trade CSV:
  - impulse ATR, body efficiency, overlap/chop, break quality, speed, follow-through, obstacle clearance
  - quality score, quality bucket, gate pass/reject reason
- Added scripts:
  - `scripts/generate-session-reversal-m15-wave1-quality-cycles.py`
  - `scripts/run-session-reversal-m15-wave1-quality-batch.ps1`
  - `scripts/analyze-session-reversal-m15-wave1-quality-cycles.py`

## Validation

- Compile: `reports/compile/metaeditor.log`
  - `Result: 0 errors, 0 warnings`
- Run root: `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/`
- Batch runs:
  - Q1 quick: 10 runs completed.
  - Full 2025: 10 runs completed.
- Timeframe check:
  - presets use H1=`16385`, M15=`15`, M5=`5`
  - all exported trades in `trades_all_scenarios.csv` have `selected_candidate_timeframe=PERIOD_M5` and `primary_entry_tf=PERIOD_M5`
  - tester period remains M15, but EA entry scan is based on `InpPrimaryEntryTF=PERIOD_M5`
- Tester config:
  - `[Experts] Enabled=0`
  - `AllowLiveTrading=0`

## Key Results

| Candidate | Trades | PF | avg_R | Net | MFE>=1R | TP |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline c10 | 318 | 0.59 | -0.1582 | -1144.89 | 24.5% | 15.4% |
| required-light | 50 | 1.34 | +0.1099 | +134.29 | 40.0% | 30.0% |
| required-light AND wave1 quality | 7 | 0.39 | -0.2733 | -48.65 | 28.6% | 14.3% |
| required-light OR wave1 quality | 87 | 0.82 | -0.0701 | -144.12 | 29.9% | 20.7% |
| wave1 quality only | 51 | 0.46 | -0.2164 | -262.10 | 23.5% | 9.8% |
| required-light OR wave1 quality + corrective exhaustion | 67 | 1.08 | +0.0274 | +44.15 | 31.3% | 25.4% |
| one-symbol required-light wave1 diagnostic | 35 | 1.74 | +0.2133 | +183.93 | 45.7% | 34.3% |

## Decision

No 2025 shallow gate candidate was found.

`required-light OR wave1 quality + corrective exhaustion` is a small positive research fragment, but only 67 trades. It does not qualify for fixed 3-year BT/OOS or promotion.

Wave1 quality alone did not create edge. Combining wave1 quality with required-light as an AND condition overfiltered and worsened performance. Combining it as OR expanded the trade count to 87 but reintroduced negative expectancy.

## Evidence

- Summary: `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/summary.md`
- Full comparison: `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/full2025_comparison.csv`
- Wave1 quality breakdown: `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/m15_wave1_quality_breakdown.csv`
- Required-light by wave1 quality: `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/required_light_by_m15_wave1_quality.csv`
- Wave1 quality x corrective exhaustion: `reports/backtest/runs/20260708_session_reversal_m15_wave1_quality/wave1_quality_x_corrective_exhaustion_breakdown.csv`
