# USDJPY Method2 S2 Short Reactivation Cycle 1

- Date: `2026-04-10`
- Family: `usdjpy_20260402_golden_method`
- Scope: `Strategy 2 sell-only breakout`
- Objective:
  - reopen the best surviving `USDJPY short` thesis after the mirrored Method1 short failed,
  - see whether `Strategy 2` can become the first realistic short-side Method2 candidate

## Starting Point

- Prior best evidence:
  - active preset with `spread 2.0` had `train +815.10 / PF 3.02 / 7 trades / DD 1.99%`
  - but latest OOS had `0 trades`
- Reconciliation note already showed:
  - current logic did reach `signal_fire`
  - the key blocked pass happened at `spread 2.20`
  - relaxing all the way to `2.3` made OOS negative

## Probe Design

- Keep the same executable `S2 sell-only breakout` core.
- Change only a small set of high-impact inputs:
  - `InpMaxSpreadPips`
  - breakout quality (`body`, `close location`, `rejection close location`)
  - `InpMaxRoundTouchesBeforeBreak`
  - `InpBreakoutExpiryBars`
  - `InpTargetRMultiple`

## Tested Presets

### `exec22`

- Spread gate:
  - `2.2`
- Train:
  - `net +815.10`
  - `PF 3.02`
  - `7 trades`
  - `max balance DD 1.99%`
- OOS:
  - `net -377.10`
  - `PF 0.38`
  - `4 trades`
  - `max balance DD 4.00%`
- Verdict:
  - pure spread loosening is still wrong

### `exec22-tight`

- Main changes:
  - `spread 2.2`
  - stronger slow-slope and breakout/retest quality
  - `max round touches 2`
  - expiry cut to `36`
- Train:
  - `net +728.94`
  - `3 trades`
  - no losing trades
- OOS:
  - `net +239.67`
  - `1 trade`
  - no losing trades

### `exec22-fast`

- Main changes:
  - `spread 2.2`
  - `max round touches 2`
  - expiry cut to `24`
  - `1.0R` target
- Train:
  - `net +396.63`
  - `2 trades`
  - no losing trades
- OOS:
  - `net +201.69`
  - `1 trade`
  - no losing trades

### `exec22-balanced`

- Main changes:
  - hybrid between `tight` and `fast`
- Train:
  - `net +396.63`
  - `2 trades`
  - no losing trades
- OOS:
  - `net +201.69`
  - `1 trade`
  - no losing trades

## Interpretation

- There is a real short-side survivor here.
- The key lesson is specific:
  - `spread 2.2` is necessary to admit the blocked executable pass,
  - but `spread loosening alone` reopens bad OOS trades,
  - so the spread change only works when paired with tighter breakout/retest quality and shorter state expiry.

## Verdict

- Promote `exec22-tight` as the current best `USDJPY short-side Method2 candidate`.
- Do not call it `operational mainline` or `standalone demo-forward candidate` yet.
- Reason:
  - both windows are positive,
  - but the sample is still too sparse for a standalone promotion claim.

## Routing Decision

- `quality12b_guarded` stays Method 1 and the only operational mainline.
- `exec22-tight` becomes:
  - the first surviving short-side Method2 candidate,
  - serious-validation inventory,
  - eligible for future coexistence testing,
  - not yet eligible for first-capital or standalone demo-forward routing.

## Next Practical Step

1. If Method2 must be treated as a second method rather than a second mainline, test `quality12b_guarded + exec22-tight` as a comparison branch.
2. If Method2 must stand on its own, a longer validation window or forward proof is still required before any promotion language.
