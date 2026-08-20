# TRENDLINE_WAVE2_FAILURE M15 state fix

## Task

Fix the unreachable M15 continuation-failure paths before considering any parameter relaxation. H4, H1, ATR thresholds, stop logic, fixed 2R, and risk controls were held constant.

## Change

- Separated M15 processing into anchor freeze, post-anchor classification, failure re-anchor, and protected-break entry functions.
- Frozen reference and protected-swing prices plus pivot/confirmation timestamps at pullback activation.
- Removed the repeated `counterStructure` gate from the active and failure states.
- Moved the optional M15 MA-slope check to the protected-break entry gate.
- Added failure re-anchoring after a confirmed clear break of the pattern extreme.
- Added the requested detailed funnel counters and six deterministic Long/Short reachability tests.

## Validation

- Compile: [MetaEditor log](../../reports/compile/trendline_wave2_failure_m15_fix.log), 0 errors / 0 warnings.
- Locked 2024 real-tick evidence: [final report](../../reports/backtest/runs/20260815_trendline_wave2_failure_m15_state_fix_final/final-report.md).
- Strategy preset changes: 0; only run identity fields differ from the original 2024 preset.
- Reachability: 6 passed / 0 failed.
- 2024 market result: 0 orders. The only H1 reversal setup expired before M15 countertrend structure, so the new M15 runtime path was not exercised by this year.

## Decision

The structural state-machine defect is fixed and compile/self-test verified. The 2024 run is insufficient evidence for live behavior or expectancy because it never reached `anchor_frozen`. Do not relax parameters on the basis of this run. A later validation window should first be used to obtain real M15 transition evidence with the same locked parameters.

