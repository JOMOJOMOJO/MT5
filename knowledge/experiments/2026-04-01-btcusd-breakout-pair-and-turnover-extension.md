# BTCUSD Breakout Pair And Turnover Extension

## Summary

- Tried to promote a faster `pair-rule` family inside `btcusd_20260401_regime_single`.
- Rejected all first pair-rule candidates in actual MT5.
- Returned to the surviving `ret24` family and probed a turnover extension around the same late-session edge.
- Promoted `long-ret24-stoch24-h8` as the current high-turnover mainline candidate.

## Pair-Rule Probe

Actual MT5 1-year results:

- `bpd6_slope_h3`
  - net `-988.15`
  - PF `0.43`
  - trades `90`
  - DD `9.98%`
- `bpd6_high12_h3`
  - net `-1099.64`
  - PF `0.70`
  - trades `240`
  - DD `12.00%`
- `roc6_rsi7_h3`
  - net `-1130.59`
  - PF `0.71`
  - trades `234`
  - DD `12.20%`
- `roc6_ret6_h3`
  - net `-1092.94`
  - PF `0.70`
  - trades `237`
  - DD `11.82%`

Verdict:

- Reject the first breakout / roc pair-rule family.
- Raw feature-lab expectancy did not survive:
  - MT5 spread,
  - entry path dependence,
  - ATR stop / timed exit reality.

## Ret24 Turnover Extension

Returned to the current positive branch:

- `long-ret24-stochd19-h8`
  - 1-year actual:
    - net `+633.90`
    - PF `1.18`
    - trades `207`
    - DD `4.86%`
  - 3-month OOS:
    - net `+352.60`
    - PF `1.35`
    - trades `65`
    - DD `1.62%`

Turnover probes:

- `long-ret24-stoch24-h8`
  - 1-year actual:
    - net `+647.84`
    - PF `1.15`
    - trades `257`
    - DD `6.17%`
  - 3-month OOS:
    - net `+400.62`
    - PF `1.29`
    - trades `87`
    - DD `2.28%`
- `long-ret24-stoch24-h6`
  - 1-year actual:
    - net `+670.21`
    - PF `1.16`
    - trades `264`
    - DD `5.93%`
  - 3-month OOS:
    - net `+363.89`
    - PF `1.28`
    - trades `88`
    - DD `2.17%`
- `long-ret24-stoch19-h8-18to24`
  - 1-year actual:
    - net `+239.63`
    - PF `1.04`
    - trades `356`
    - DD `8.98%`

## Interpretation

- The useful move was not opening a new regime.
- The useful move was widening the oscillator allowance inside the already-positive late-session `ret24` thesis.
- `stoch24` adds turnover without collapsing OOS quality.
- Extending the session window from `20-24` to `18-24` added trades, but quality decayed too much.

## Current Verdict

- Promote `btcusd_20260401_regime_single-long-ret24-stoch24-h8` as the current high-turnover mainline candidate.
- Keep `btcusd_20260401_regime_single-long-ret24-stoch19-h8` as the quality reference branch.
- Keep `btcusd_20260401_regime_single-long-ret24-stoch24-h6` as a secondary turnover-heavy variant, not the mainline.

## Next Step

- Do not open another pair-rule family before the current `ret24-stoch24` branch is exhausted.
- Next cycle should focus on:
  - execution realism,
  - spread sensitivity,
  - possibly a complementary short branch only if it clears full-year actual.
