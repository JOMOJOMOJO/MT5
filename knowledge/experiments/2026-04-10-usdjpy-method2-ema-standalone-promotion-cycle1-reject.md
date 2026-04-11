# USDJPY Method 2 EMA Standalone Promotion Cycle 1 Reject

- Date: `2026-04-10`
- Family: `usdjpy_20260402_ema_continuation_long`
- Objective: determine whether the current `EMA continuation` branch can be promoted from `research-qualified second bucket` to an independently operable standalone branch

## Baseline Reconfirm

- preset: `usdjpy_20260402_ema_continuation_long-london-loose.set`
- train `2025-04-01` to `2025-12-31`:
  - `net +1057.57 / PF 1.12 / 88 trades / DD 12.46%`
- OOS `2026-01-01` to `2026-03-31`:
  - `net +738.46 / PF 2.02 / 11 trades / DD 3.96%`

## Targeted Promotion Probes

### guarded

- preset: `usdjpy_20260410_ema_continuation_method2-guarded.set`
- train:
  - `net -707.44 / PF 0.85 / 49 trades / DD 15.57%`

### quick

- preset: `usdjpy_20260410_ema_continuation_method2-quick.set`
- train:
  - `net -680.99 / PF 0.85 / 47 trades / DD 15.76%`

### carry

- preset: `usdjpy_20260410_ema_continuation_method2-carry.set`
- train:
  - `net +2856.38 / PF 3.10 / 24 trades / DD 3.93%`
- OOS:
  - `net 0.00 / PF 0.00 / 0 trades / DD 0.00%`

### swing

- preset: `usdjpy_20260410_ema_continuation_method2-swing.set`
- train:
  - `net +497.95 / PF 1.07 / 66 trades / DD 14.46%`

### balanced

- preset: `usdjpy_20260410_ema_continuation_method2-balanced.set`
- train:
  - `net -146.30 / PF 0.97 / 47 trades / DD 14.53%`

## Interpretation

- The current `EMA continuation` family still has a useful behavioral edge.
- But it fails the repo promotion requirement for a standalone branch because no candidate cleared both:
  - long-window actual quality, and
  - executable recent OOS evidence.
- `carry` was the only train winner with strong PF, but it did so by becoming too sparse and produced `0 trades` in the latest OOS window.
- The other variants either reverted below `PF 1.0` or remained too weak on long-window train quality.

## Verdict

- Reject standalone promotion for Method 2 in this cycle.
- Keep Method 2 as:
  - `research-qualified second bucket`
  - `coexistence-only sidecar`
- Do not open a standalone release packet for this family.

## Coexistence Decision

- The correct operating shape remains:
  - Method 1 `quality12b_guarded` as the only quality-first mainline
  - Method 2 `EMA continuation` as a sidecar inside the combined engine
- The coexistence track remains:
  - `.company/release/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.md`
- This track is useful as a turnover comparison branch, but it is still not the first-capital route.
