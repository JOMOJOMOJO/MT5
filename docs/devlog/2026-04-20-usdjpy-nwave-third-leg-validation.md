# 2026-04-20 - usdjpy-nwave-third-leg-validation

## Summary

- task: design, scaffold, and minimally validate a new standalone `Dow Fractal N-Wave Third-Leg Engine`
- EA / family: `USDJPY Dow Fractal N-Wave Third-Leg Engine`
- decision status: rejected after minimal matrix validation

## Background

- Dow HS was already closed because OOS repeatability was weak and fixed-TP diagnostics did not rescue the entry family.
- the generic local sweep family was already closed because actual aggregate stayed below `PF 1` and good OOS slices were sparse.
- the next hypothesis was that `wave1 -> wave2 -> invalidation-line break` could capture the start of `wave3` better than named reversal patterns or generic sweep failure.

## Changes

- added a new standalone EA scaffold at `mql/Experts/usdjpy_20260420_n_wave_third_leg_engine.mq5`
- replaced the prior pattern logic with:
  - context phases including correction-candidate buckets
  - `wave1 / wave2 / invalidation line` detection
  - subtype telemetry for `hs_wave2`, `double_top_wave2`, and `lower_high_wave2`
  - execution triggers for invalidation close break, retest reject, and recent swing breakdown
- added a dedicated validator at `plugins/mt5-company/scripts/usdjpy_n_wave_third_leg_validation.py`
- added Tier A / Tier AB presets for the new family

## Evidence Links

- spec:
  - `knowledge/experiments/2026-04-20-usdjpy-n-wave-third-leg-engine-spec.md`
- validation review:
  - `knowledge/experiments/2026-04-20-usdjpy-n-wave-third-leg-validation-review.md`
- backtest summary:
  - `reports/backtest/sweeps/2026-04-20-usdjpy-nwave3-validation/results/summary.md`
- machine-readable results:
  - `reports/backtest/sweeps/2026-04-20-usdjpy-nwave3-validation/results/results.json`
- compile log:
  - `reports/compile/metaeditor.log`

## Outcome

- compile passed and the `27`-run minimal matrix completed.
- `H1 x M15 x M5` produced zero inventory.
- `M30 x M10 x M5` was the least bad actual pair, but still negative and not repeated in OOS.
- actual inventory skewed toward `hs_wave2` and `neckline_low`, while the dominant loss path remained `acceptance_back_above_invalidation_line`.
- time-stop and runner exits produced some positive outcomes, but not enough to offset the acceptance failures.

## Conclusion

- the N-wave framing improved structural clarity, but it did not prove a durable standalone edge.
- the family should remain closed rather than extended with rescue filters.
