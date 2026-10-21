# quality12b: behavior-preserving module extraction

## Scope

Refactored `mql/Experts/usdjpy_20260402_round_continuation_long.mq5` (M15 quality12b). This is not the older M5/M1 ThreeWave EA.

The main file decreased from 2,315 to 429 lines. Eight modules under `mql/Include/Quality12b/` contain configuration, runtime risk, market data, position management, price structure, signals, orders, and telemetry/control. Event handlers remain in the main file. No algorithm, parameter default, SL/TP, or preset was changed. This is maintainability work, not a speed optimization.

## Evidence

- [Source equivalence](source_equivalence.json): expanding the extracted modules reproduces the frozen original source byte for byte; SHA256 `e8a3376a9d5a07089f7373592fbabcf7ccd6513781b7940540ef2ba421c4cd20`.
- All 163 inputs and their order are preserved.
- [Compile log](compile.log): 0 errors, 0 warnings.
- Python tooling checks: 30 tests passed. `git diff --check` passed.
- Original source preserved as [before.mq5](before.mq5).
- No EX5 synchronization to other running terminals was performed.

Source equivalence is not a claim of EX5 byte identity or completed runtime validation. An isolated 2022 runtime control is prepared under [q12_refactor_check_20261006](../q12_refactor_check_20261006/manifest.json), comparing the refactored baseline without the observer against the recent research run. Runtime status is recorded in that package.

The known floating-point spread boundary issue is intentionally unchanged: repairing it would alter the entry population and needs a separate controlled experiment.
