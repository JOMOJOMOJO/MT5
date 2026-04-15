# USDJPY Dow HS Family Validation Review

Date: 2026-04-15

Target EA: `mql/Experts/usdjpy_20260414_dow_fractal_head_shoulders_engine.mq5`

Artifacts:

- `reports/backtest/sweeps/2026-04-15-usdjpy-dow-hs-family-validation/results/results.json`
- `reports/backtest/sweeps/2026-04-15-usdjpy-dow-hs-family-validation/results/summary.md`
- `plugins/mt5-company/scripts/usdjpy_dow_hs_family_validation.py`

## 1. Compile / Run Feasibility

- compile: success
- tester run: success
- total executed runs: 63
  - Phase 1: 18
  - Phase 2: 45

Notes:

- MetaEditor returned exit code `1`, but `reports/compile/metaeditor.log` reported `0 errors, 0 warnings`.
- Phase 2 required only a timeframe allowlist expansion:
  - context: `M30`
  - pattern: `M10`
  - execution: `M5`
- No entry or exit rule logic was changed for Phase 2.

## 2. Phase 1 Matrix

Fixed:

- Tier A strict only
- short-only
- partial target `fib 38.2`
- final target `fib 61.8`
- hold bars `24`
- scaffold exit unchanged

Pairs:

1. `H1 context x M15 pattern x M3 execution`
2. `M15 context x M5 pattern x M3 execution`

Triggers:

1. `EXEC_NECK_CLOSE_CONFIRM`
2. `EXEC_NECK_RETEST_FAILURE`
3. `EXEC_RECENT_SWING_BREAK`

## 3. Phase 1 Major Results

### Best actual pair-level aggregate

| pair | trades | PF | net | avg realized R |
|---|---:|---:|---:|---:|
| `H1 x M15 x M3` | 61 | 0.56 | -97.61 | -0.0474 |
| `M15 x M5 x M3` | 66 | 0.24 | -458.17 | -0.2060 |

### Trigger aggregate

| window | trigger | trades | PF | net | avg realized R |
|---|---|---:|---:|---:|---:|
| train | neck close | 48 | 0.22 | -282.56 | -0.1748 |
| train | neck retest | 2 | 0.00 | -10.31 | -0.1525 |
| train | recent swing | 26 | 0.26 | -110.18 | -0.1254 |
| OOS | neck close | 0 | 0.00 | 0.00 | 0.0000 |
| OOS | neck retest | 0 | 0.00 | 0.00 | 0.0000 |
| OOS | recent swing | 7 | 0.00 | -17.64 | -0.0740 |
| actual | neck close | 78 | 0.38 | -342.95 | -0.1304 |
| actual | neck retest | 4 | 0.33 | -13.04 | -0.0967 |
| actual | recent swing | 45 | 0.21 | -199.79 | -0.1317 |

## 4. Phase 1 Inventory / OOS / Collapse

- OOS inventory existed, but only `recent_swing_break` fired.
- `neck_close_confirm` and `neck_retest_failure` produced `0` OOS trades.
- Actual inventory was not sparse in count, but quality was poor across all active triggers.
- Subtype collapse was already visible:
  - side: only short by design
  - pattern: effectively only `triple_top_head_shoulders`
  - OOS trigger: only `exec_recent_swing_break`

Phase 1 diagnosis:

- the family is not dead by inventory count
- the family is dead as a clean trigger comparison
- Phase 2 was justified because OOS trigger comparison collapsed before quality comparison became meaningful

## 5. Phase 2 Matrix

Pairs:

1. `M30 x M15 x M3`
2. `M15 x M10 x M3`
3. `M30 x M10 x M3`
4. `M15 x M5 x M3`
5. `M15 x M10 x M5`

Triggers remained the same.

## 6. Phase 2 Major Results

### Actual pair-level aggregate

| pair | trades | PF | net | avg realized R |
|---|---:|---:|---:|---:|
| `M15 x M10 x M5` | 41 | 0.57 | -100.04 | -0.0709 |
| `M30 x M15 x M3` | 55 | 0.44 | -129.96 | -0.0703 |
| `M30 x M10 x M3` | 55 | 0.31 | -308.07 | -0.1660 |
| `M15 x M10 x M3` | 68 | 0.22 | -324.63 | -0.1412 |
| `M15 x M5 x M3` | 66 | 0.24 | -458.17 | -0.2060 |

### OOS pair-level aggregate

| pair | trades | PF | net | avg realized R |
|---|---:|---:|---:|---:|
| `M30 x M10 x M3` | 10 | 0.00 | -200.17 | -0.5834 |
| `M15 x M10 x M3` | 2 | 0.00 | -37.69 | -0.5596 |
| `M15 x M10 x M5` | 2 | 0.00 | -73.02 | -1.0472 |
| `M15 x M5 x M3` | 1 | 0.00 | -6.67 | -0.1911 |
| `M30 x M15 x M3` | 0 | 0.00 | 0.00 | 0.0000 |

### Sparse positive survivors

| run | actual trades | PF | net | comment |
|---|---:|---:|---:|---|
| `M30 x M10 x M3 x neck_retest_failure` | 6 | 1.22 | 2.92 | OOS had 1 trade, full loss |
| `M15 x M10 x M5 x neck_retest_failure` | 3 | 1.08 | 0.59 | OOS had 0 trades |

## 7. M30 / M10 / M5 Execution Effects

### What improved

- `M30` and `M10` increased inventory.
- `M15 x M10 x M5` reduced actual loss severity relative to the original baseline.
- `M30 x M15 x M3` was the cleanest non-sparse repeatable pair on actual, though still negative.

### What did not improve

- OOS quality did not improve.
- Wider timeframe candidates created more losing inventory, not better inventory.
- `M30 x M10 x M3` created the most OOS trades, but every OOS trade lost.
- `M15 x M10 x M5` improved actual PF to `0.57` at pair level, but OOS still lost every trade it produced.

## 8. Telemetry Diagnosis

Repeated patterns:

- context was concentrated in `ctx_range_top` and `ctx_up_exhaustion`
- pattern was almost entirely `triple_top_head_shoulders`
- wins were not explained by a robust trigger family
- exits were dominated by:
  - `acceptance_back_above_neck` losses
  - `time_stop` salvage

Important example:

- `M15 x M10 x M5 x neck_close_confirm` had near-flat actual expectancy (`avg realized R = -0.0270`), but its exit breakdown still showed `time_stop` as the main positive bucket and `acceptance_back_above_neck` as the main drag.
- This means the family still relies on inventory salvage rather than on a clean reversal-entry edge.

## 9. Final Decision

Decision: `Reject`

Reason:

1. Phase 1 OOS collapsed into a single trigger subtype.
2. Phase 2 increased inventory, but only by adding lower-quality losing inventory.
3. No repeatable pair achieved `PF > 1` on actual together with real OOS confirmation.
4. The only positive actual runs were sparse survivors.
5. Telemetry still describes a family that bleeds through neckline acceptance failure and gets partially rescued by time stop, not a family with a robust standalone reversal-entry edge.

This family is not strong enough as a standalone promotion candidate in its current form.
