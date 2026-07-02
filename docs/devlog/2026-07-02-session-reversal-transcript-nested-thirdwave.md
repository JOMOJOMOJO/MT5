# Session Reversal Transcript Nested Third-Wave Diagnostic

## Task

Bring `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` closer to the transcript concept:

- H1 context wave.
- M15 structure/reversal wave.
- M5 first-pullback/retest entry.
- 75SMA/Granville-style context.
- Exit when the lower M5 structure breaks.

## Changes

- Added transcript context inputs and diagnostics to the EA:
  - `InpTranscriptContextMode`
  - `InpTranscriptSmaPeriod`
  - `InpTranscriptRequireStructureBreak`
  - `InpTranscriptRequireSmaReclaim`
  - `InpTranscriptUsePrimaryFailureExit`
- Added CSV diagnostics for transcript context, 75SMA states, M15/M5 break age, and break levels.
- Added optional M5 structure/neckline/MA failure exit.
- Added scripts:
  - `scripts/generate-session-reversal-transcript-cycles.py`
  - `scripts/analyze-session-reversal-transcript-cycles.py`

## Validation

- Compile: `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_transcript_compile.log`
  - Result: 0 errors, 0 warnings.
- Search/report folder: `reports/backtest/runs/20260702_session_reversal_transcript_nested_thirdwave/`

## Findings

- The initial Q1 run did not produce a fresh MT5 report within 15 minutes, so the search window was reduced to January 2025.
- The first five Jan cycles produced 0 trades because the generated preset used `InpTopContextTF=60`. In MQL5, H1 must use the `PERIOD_H1` enum value `16385`; the invalid H1 value made the transcript filter reject every candidate.
- After correcting H1 to `16385`, the five practical cycles were c6-c10.
- Requiring M15 confirmed swing break as a hard gate was too restrictive. Making it diagnostic restored projected annual trade count above 300.
- The best Jan row was `c10_jan_counter_diag_sma_failure_exit_relaxed_retest`:
  - 31 trades in Jan 2025
  - PF 0.51
  - avg_R -0.2026
  - net -156.71
- 2025 fixed validation for c10:
  - 318 trades
  - PF 0.59
  - avg_R -0.1582
  - net -1144.89
  - max DD 1179.96
  - full SL 10.4%
  - TP 15.4%

## Decision

No operating candidate.

The transcript-style implementation restores trade count only after loosening M15 break confirmation, but the expectancy is strongly negative. The optional M5 failure exit reduces full SL frequency, but most trades exit by time without enough follow-through. The current lower-timeframe neckline/retest definitions still do not isolate the "initial third wave" described in the transcript.
