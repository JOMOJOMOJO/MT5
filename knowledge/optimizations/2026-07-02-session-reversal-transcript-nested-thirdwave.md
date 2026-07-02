# Session Reversal Transcript Nested Third-Wave Optimization Note

## Hypothesis

The transcript's idea is closer to:

- H1 move/context.
- M15 reversal or adjustment wave.
- M5 chart-pattern first pullback for the lower-timeframe third wave.
- 75SMA/Granville as context.
- Exit when the M5 structure breaks, not only fixed TP/SL.

## Search

EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`

Artifacts:

- `reports/backtest/runs/20260702_session_reversal_transcript_nested_thirdwave/summary.md`
- `reports/backtest/runs/20260702_session_reversal_transcript_nested_thirdwave/comparison.csv`
- `reports/backtest/runs/20260702_session_reversal_transcript_nested_thirdwave/full2025_comparison.csv`

## Results

January 2025 search:

- M15 confirmed break as hard gate: 0 trades.
- M15 break diagnostic only:
  - c6: 28 trades, PF 0.49, avg_R -0.3021.
  - c7: 38 trades, PF 0.54, avg_R -0.2707.
  - c8: 27 trades, PF 0.47, avg_R -0.3144.
  - c9: 28 trades, PF 0.49, avg_R -0.2210.
  - c10: 31 trades, PF 0.51, avg_R -0.2026.

2025 fixed validation for c10:

- 318 trades.
- PF 0.59.
- avg_R -0.1582.
- net -1144.89.
- max DD 1179.96.
- full SL rate 10.4%.
- TP rate 15.4%.

## Lessons

- In MQL5 `.set` generation, H1 should be `16385` (`PERIOD_H1`), not `60`.
- The transcript idea should not hard-gate M15 break confirmation at the first research pass. It can be diagnostic, because a hard gate can eliminate the early third-wave entry zone.
- M5 failure exit reduced full SL frequency, but did not create edge. Most losses shifted into time exits or partial losses, meaning the entry still lacks follow-through quality.
- Current double-top/double-bottom/head-and-shoulders neckline retest detection is too generic. It finds many retests, but not enough of the specific nested "third-wave launch" described in the transcript.

## Decision

Reject this implementation as an operating candidate. Do not advance to 3-year fixed BT or OOS.

The next useful experiment is not fine tuning ATR/retest thresholds. It should redefine the lower-timeframe pattern quality: nested pattern inside pattern, 2-wave invalidation, and a clearer post-break acceptance rule before entry.
