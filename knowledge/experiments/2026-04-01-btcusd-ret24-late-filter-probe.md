# BTCUSD Ret24 Late Filter Probe

## Summary

- Started from the best positive high-turnover branch inside `btcusd_20260401_regime_single`:
  - `long-ret24`
- Re-checked the feature lab instead of tuning blindly.
- Confirmed the important split:
  - `ret24` works in the `late` session,
  - it does not generalize cleanly across Asia, London, and NY on the train window.
- Tested five late-session quality filters in actual MT5:
  - `stoch_d`
  - `bb_z`
  - `high_break_24`
  - `tick_flow_signed_3`
  - `tick_volume_z`

## Analysis View

- The raw `ret24 <= -0.0057` rule is not an all-day edge.
- The repeatable version is:
  - late-session downside extension,
  - followed by a still-weak oscillator state,
  - before the bounce has already normalized.
- `volume/flow` helped, but not as a stand-alone entry thesis.
- On this broker feed:
  - DOM is unavailable,
  - tick volume is still useful as a proxy for urgency and crowding,
  - signed tick-flow is useful as a ranking / exclusion filter,
  - neither one is yet strong enough to replace the core price-extension rule.

## Actual MT5 1-Year Results

Baseline reference:

- `long-ret24`
  - net `+143.27`
  - PF `1.02`
  - trades `368`
  - DD `10.43%`

Late-session filter probes:

- `long-ret24-stochd15`
  - net `+451.93`
  - PF `1.15`
  - trades `163`
  - DD `7.04%`
- `long-ret24-stochd19`
  - net `+555.66`
  - PF `1.14`
  - trades `204`
  - DD `7.20%`
- `long-ret24-stochd24`
  - net `+484.51`
  - PF `1.10`
  - trades `250`
  - DD `7.75%`
- `long-ret24-flow033`
  - net `+210.17`
  - PF `1.04`
  - trades `236`
  - DD `7.95%`
- `long-ret24-volume033`
  - net `+65.90`
  - PF `1.02`
  - trades `162`
  - DD `7.28%`
- `long-ret24-highbreak523`
  - net `+1.57`
  - PF `1.00`
  - trades `194`
  - DD `6.91%`
- `long-ret24-bbz155`
  - net `+75.79`
  - PF `1.31`
  - trades `11`
  - DD `1.64%`
  - rejected as too sparse to count as a high-turnover branch

## Exit / Risk Probe

Focused on `stochd19` because it preserved more turnover than `stochd15`.

- Earlier unfiltered exit probe `h8_s10_tp05` was rejected immediately:
  - net `-1130.76`
  - PF `0.77`
  - trades `378`
  - DD `12.00%`
- `stochd19-h8`
  - net `+633.90`
  - PF `1.18`
  - trades `207`
  - DD `4.86%`
- `stochd19-s10`
  - net `+430.19`
  - PF `1.09`
  - trades `221`
  - DD `10.15%`
- `stochd19-h8s10`
  - net `+471.21`
  - PF `1.11`
  - trades `223`
  - DD `7.43%`

Verdict:

- Shorter hold helped.
- Tightening the stop did not help enough.
- The best current sub-branch is `long-ret24-stochd19-h8`.

## OOS 3-Month Check

- `long-ret24-stochd15`
  - net `+388.94`
  - PF `1.52`
  - trades `47`
  - DD `2.04%`
- `long-ret24-stochd19`
  - net `+417.88`
  - PF `1.37`
  - trades `65`
  - DD `1.89%`
- `long-ret24-stochd19-h8`
  - net `+352.60`
  - PF `1.35`
  - trades `65`
  - DD `1.62%`

## Interpretation

- The important improvement was not “add more indicators”.
- The useful move was:
  - keep the price-extension thesis,
  - constrain it to the session where it is actually positive,
  - use oscillator / flow-style features as quality filters.
- `stoch_d` was the strongest late-session quality filter.
- `tick volume` and `tick flow` remain useful secondary views, but they are still weaker than `stoch_d` for actual 1-year MT5 promotion.

## Current Verdict

- Promote `btcusd_20260401_regime_single-long-ret24-stochd19-h8` as the current best high-turnover research candidate.
- Keep `stochd15` as the quality reference for the same branch.
- Do not discuss live promotion yet:
  - 1-year PF is improved but still below a comfortable live threshold,
  - actual turnover is better than the old quality family but still below the original multi-trade-per-day target.

## Next Step

- Keep `btcusd_20260401_regime_single` as the main high-turnover research family.
- Use `long-ret24-stochd19-h8` as the default branch for the next cycle.
- Next cycle focus:
  - sidecar session expansion only if it passes train/OOS,
  - execution realism,
  - possibly a second valid long regime,
  - no new short branch unless the 1-year actual turns clearly positive.
