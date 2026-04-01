# BTCUSD Regime Single Stop And Volume Probe

## Summary

- Probed execution realism first on the current high-turnover mainline:
  - `long-ret24-stoch24-h8`
- Tested:
  - fixed profit targets at `0.25R` and `0.50R`
  - wider initial stop at `1.50 ATR`
  - follow-up tick-volume filters on top of the wider-stop branch

## Actual MT5 Results

### Baseline Reference

- `long-ret24-stoch24-h8`
  - 1-year actual:
    - net `+647.84`
    - PF `1.15`
    - trades `257`
    - DD `6.17%`
  - OOS 3-month:
    - net `+400.62`
    - PF `1.29`
    - trades `87`
    - DD `2.28%`

### Exit / Stop Probes

- `tp0.25R`
  - 1-year actual:
    - net `-500.72`
    - PF `0.84`
    - trades `417`
    - DD `7.11%`
- `tp0.50R`
  - 1-year actual:
    - net `-214.92`
    - PF `0.94`
    - trades `349`
    - DD `7.15%`
- `stop1.50ATR`
  - 1-year actual:
    - net `+609.87`
    - PF `1.17`
    - trades `240`
    - DD `4.71%`
  - OOS 3-month:
    - net `+292.80`
    - PF `1.26`
    - trades `84`
    - DD `2.03%`

### Turnover Recovery Probe

- `hold6 + stop1.50ATR`
  - 1-year actual:
    - net `+511.22`
    - PF `1.15`
    - trades `245`
    - DD `4.77%`

### Tick-Volume Filter Probes On Top Of `stop1.50ATR`

- `tick_volume_z >= 0.11`
  - 1-year actual:
    - net `+570.38`
    - PF `1.28`
    - trades `136`
    - DD `2.60%`
  - OOS 3-month:
    - net `+16.48`
    - PF `1.03`
    - trades `35`
    - DD `1.84%`
- `tick_volume_z >= 0.64`
  - 1-year actual:
    - net `+484.74`
    - PF `1.35`
    - trades `94`
    - DD `2.64%`
  - OOS 3-month:
    - net `-21.12`
    - PF `0.93`
    - trades `17`
    - DD `1.87%`

## Interpretation

- The profit-target idea was wrong.
- Higher win rate from a small fixed `R` target destroyed expectancy after MT5 execution reality.
- The wider `1.50 ATR` stop improved:
  - 1-year PF,
  - 1-year drawdown,
  - and OOS drawdown,
  while staying positive OOS.
- Tick-volume filters looked attractive in-sample but overfit on the 3-month OOS window.
- `hold6 + stop1.50ATR` did not recover enough turnover to justify replacing the wider-stop `hold8` branch.

## Verdict

- Promote `long-ret24-stoch24-h8-stop1.50ATR` as the current high-turnover mainline inside `btcusd_20260401_regime_single`.
- Reject `tp0.25R` and `tp0.50R`.
- Reject the current tick-volume filters as promotion candidates.
- Keep volume and flow as research tools, not current live filters.

## Next Step

- Do not keep stacking in-sample filters on `ret24-stoch24`.
- Open the next cycle from one of these two directions:
  - a second positive long regime that complements late-session `ret24`,
  - or a short branch that survives full-year actual, not just OOS.
