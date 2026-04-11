# USDJPY Method2 Triple-Structure Short Cycle 1 Reject

## Objective

- Turn `usdjpy_20260411_triple_structure_method2_scaffold.mq5` into a `USDJPY / HTF=M15 / LTF=M5` `short-only` standalone Method2 candidate.
- Compare two grade modes on the same cost model:
  - `Strong only`
  - `Strong + Standard`
- Keep the score additive and avoid rescuing the family by stacking extra confirmation layers.

## Assets

- EA:
  - `mql/Experts/usdjpy_20260411_triple_structure_method2_scaffold.mq5`
- Presets:
  - `reports/presets/usdjpy_20260411_triple_structure_method2_scaffold-strong-only.set`
  - `reports/presets/usdjpy_20260411_triple_structure_method2_scaffold-strongstd.set`
- Tester configs:
  - `reports/backtest/usdjpy_20260411_triple_structure_method2_scaffold-strong-only-train-9m.ini`
  - `reports/backtest/usdjpy_20260411_triple_structure_method2_scaffold-strong-only-oos-3m.ini`
  - `reports/backtest/usdjpy_20260411_triple_structure_method2_scaffold-strong-only-actual-16m.ini`
  - `reports/backtest/usdjpy_20260411_triple_structure_method2_scaffold-strongstd-train-9m.ini`
  - `reports/backtest/usdjpy_20260411_triple_structure_method2_scaffold-strongstd-oos-3m.ini`
  - `reports/backtest/usdjpy_20260411_triple_structure_method2_scaffold-strongstd-actual-16m.ini`

## Implementation

- Forced the cycle to `short-only`:
  - `InpEnableLong=false`
  - `InpEnableShort=true`
  - `InpTrendTimeframe=M15`
  - `InpSignalTimeframe=M5`
- Added explicit grade gating:
  - `InpEntryGradeMode`
  - `InpStandardPatternScore=6`
  - `InpStrongPatternScore=8`
- Added per-trade telemetry written to `FILE_COMMON` for score, grade, breakout type, range bucket, stop distance, and exit outcome review.
- Added tie-break behavior so multiple same-bar candidates prefer the stronger breakout body.
- Ran one repair cycle after the first baseline:
  - removed the short-side score reward for upper-range bullish context,
  - instead rewarded mid-to-lower HTF range position, lower-high context, and bearish EMA structure.

## Compile

- `reports/compile/usdjpy_20260411_triple_structure_method2_scaffold.log`
- Result:
  - `0 errors`
  - `0 warnings`

## First Baseline Read

The original all-day score map already produced enough frequency, so the family did not fail because it was too sparse.

- `Strong only / actual 16m`
  - `net -706.10 / PF 0.64 / 169 trades / max balance DD 8.02%`
- `Strong + Standard / actual 16m`
  - `net -727.64 / PF 0.44 / 91 trades / max balance DD 8.08%`

That was enough evidence to justify a score reweight cycle, not a stricter confirmation layer.

## Final Validation Results

### Strong only

- Train `2025-04-01` to `2025-12-31`
  - `net -595.65 / PF 0.83 / 325 trades / max balance DD 7.88%`
- OOS `2026-01-01` to `2026-04-01`
  - `net -781.02 / PF 0.58 / 167 trades / max balance DD 7.81%`
- Actual `2024-11-26` to `2026-04-01`
  - `net -682.59 / PF 0.46 / 91 trades / max balance DD 8.19%`

### Strong + Standard

- Train `2025-04-01` to `2025-12-31`
  - `net -590.38 / PF 0.84 / 330 trades / max balance DD 7.92%`
- OOS `2026-01-01` to `2026-04-01`
  - `net -801.93 / PF 0.58 / 163 trades / max balance DD 8.02%`
- Actual `2024-11-26` to `2026-04-01`
  - `net -727.64 / PF 0.44 / 91 trades / max balance DD 8.08%`

## Trade Review

- `Strong only` beat `Strong + Standard`, but both were far below the repo floor.
- The family already cleared the user's frequency requirement in all-day mode.
  - Frequency was not the bottleneck.
  - The bottleneck was negative expectancy.
- Exit profile on `Strong only / actual 16m`:
  - `sl`: `24 trades / net -809.22`
  - `time_stop`: `63 trades / net -90.35 / PF 0.80`
  - `tp`: `4 trades / net +216.98`
- Score buckets on `Strong only / actual 16m` were not monotonic enough to trust:
  - `8`: `PF 0.14`
  - `9`: `PF 0.41`
  - `10`: `PF 0.51`
  - `11`: `PF 1.32`
  - `12`: `PF 1.30`
- That means the additive scoring doctrine is inspectable, but the current pattern definition is still assigning too many weak shorts to passing grades.

## Verdict

- Verdict: `reject`
- Reason:
  - neither grade mode cleared the standalone promotion floor,
  - the family failed with enough trades, so the issue is structural quality rather than sample scarcity,
  - the score-reweight repair did not rescue the family,
  - `Strong + Standard` widened the trade set without adding value.

## Promotion Decision

- Do not call this family `operable`.
- Do not rotate this branch into `ops/...-demo-prep`.
- Do not merge this Method2 family with Method1.
- Keep the scaffold and reports as research evidence only.

## Reusable Lesson

- For this `USDJPY M15 x M5` triple-structure short family, `count` can be manufactured without difficulty.
- The hard problem is that the actual passing inventory is broad, not concentrated, and losses are still stop-driven.
- When `Strong only` already has enough frequency and still fails badly, the next move is not another small filter adjustment. It is a fresh short-side thesis.
