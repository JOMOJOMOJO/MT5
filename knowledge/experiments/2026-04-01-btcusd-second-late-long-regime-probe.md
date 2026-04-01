# BTCUSD Second Late Long Regime Probe

## Intent

- After `long-ret24-stochd19-h8` became the best current high-turnover branch, the next question was whether a second late-session long regime could be added without degrading actual MT5 quality.
- Candidate families came from the corrected spread-aware feature lab:
  - `ema_gap_50_100`
  - `close_vs_ema50`
  - `low_break_24`

## Why These Were Chosen

- Raw analysis on the late-session slice showed these rules could retain:
  - positive train net edge after spread,
  - positive test net edge after spread,
  - higher trades/day than the current `ret24` branch in some cases.
- The strongest raw candidates were:
  - `ema_gap_50_100 <= -1.6928` with `stoch_d <= 24`
  - `close_vs_ema50 <= -1.7790` with `stoch_d <= 24`
  - `low_break_24 <= 1.0065` with `stoch_d <= 24`

## Actual MT5 1-Year Results

### EMA50/100 branch

- `ema50100_stoch24_h12`
  - net `-355.04`
  - PF `0.86`
  - trades `122`
  - DD `8.76%`
- `ema50100_stoch19_h12`
  - net `-398.61`
  - PF `0.82`
  - trades `102`
  - DD `9.33%`
- `ema50100wide_stoch24_h12`
  - net `-268.05`
  - PF `0.93`
  - trades `196`
  - DD `7.20%`

### Close-vs-EMA50 branch

- `close50_stoch24_h12`
  - net `-47.07`
  - PF `0.99`
  - trades `394`
  - DD `10.78%`
- `close50tight_stoch24_h12`
  - net `-533.05`
  - PF `0.92`
  - trades `283`
  - DD `11.77%`

### Low-break branch

- `low24_stoch24_h12`
  - net `-872.91`
  - PF `0.86`
  - trades `282`
  - DD `12.00%`

## Verdict

- Reject all current second late-session long regime probes as promotion candidates.
- `close50_stoch24_h12` was the least bad, but still failed:
  - PF stayed below `1.0`,
  - drawdown stayed too high for a meaningful sidecar promotion.
- The current mainline inside `btcusd_20260401_regime_single` remains:
  - `long-ret24-stochd19-h8`

## Interpretation

- Raw feature-lab strength was not enough.
- The second-regime ideas did not survive the full MT5 execution path:
  - spread,
  - bar execution assumptions,
  - realized path dependency over the full 1-year actual window.
- This is a good example of why the company should not promote from feature lab directly.

## Next Step

- Keep `long-ret24-stochd19-h8` as the only promoted high-turnover research branch.
- Do not add a second long regime until a new candidate clears:
  - positive 1-year actual net,
  - PF clearly above `1.0`,
  - acceptable drawdown,
  - no collapse versus the current mainline branch.
