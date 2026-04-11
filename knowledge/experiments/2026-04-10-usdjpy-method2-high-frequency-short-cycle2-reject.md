# USDJPY Method2 High-Frequency Short Cycle 2 Reject

## Objective

- Build a standalone `short-only` Method2 candidate that is:
  - materially higher frequency than the sparse `S2 sell breakout` survivor,
  - at least around `1 trade per 3 days`,
  - still strong enough to be described as an operational candidate.

## Skills Used

- `research-director`
- `systematic-ea-trader`
- `risk-manager`

## Cycle Verdict

- Verdict: `reject`
- Reason:
  - it is possible to raise `USDJPY short-only` trade count above the user's floor,
  - but every high-frequency family tested in actual MT5 lost too much quality after friction.

## Family 1: Late Quiet Spike Short

- EA:
  - `mql/Experts/usdjpy_20260410_late_quiet_spike_short_guarded.mq5`
- Thesis:
  - `USDJPY / M15 / short-only`
  - late-session quiet-volume overextension fade
  - short after price is stretched above `EMA20`
  - structure-aware ATR stop
  - short holding horizon aligned to `3-12` bars

### Train Results

- `baseline`
  - `net -139.31 / PF 0.30 / 15 trades`
- `active`
  - `net -554.89 / PF 0.54 / 138 trades`
- `strict`
  - `0 trades`
- `active-timeonly`
  - `net -785.65 / PF 0.39 / 122 trades`
- `quiet70-timeonly`
  - `net -689.94 / PF 0.24 / 84 trades`
- `stoch83-timeonly`
  - `net -801.02 / PF 0.34 / 95 trades`

### Read

- The signal family can hit the user's turnover requirement.
- But the only variants with enough trades were clearly negative in actual MT5.
- Tightening the filters kills the sample before quality is rescued.
- Removing the fixed `R` target and forcing time-only exits made the loss profile worse, not better.

## Family 2: Intrabar Close-Location Short Transfer

- Engine:
  - `mql/Experts/btcusd_20260401_intrabar_reversal.mq5`
- USDJPY transfer presets:
  - `reports/presets/usdjpy_20260410_intrabar_reversal-short-all-cl84-h12-s15.set`
  - `reports/presets/usdjpy_20260410_intrabar_reversal-short-all-cl84-h6-s15.set`
- Thesis:
  - `USDJPY / M15 / short-only`
  - fade bars that close very near the high
  - time exit after `6` or `12` bars

### Train Results

- `cl84-h12-s15`
  - `net -1183.32 / PF 0.57 / 193 trades`
- `cl84-h6-s15`
  - `net -1193.89 / PF 0.59 / 239 trades`

### Read

- This construction also clears the user's turnover floor easily.
- But it loses even faster than the quiet-spike family.
- So this is not a viable rescue path for Method2 on `USDJPY`.

## Current Short-Side Status

- The old sparse survivor still stands:
  - `usdjpy_20260410_method2_s2_short_guarded`
  - good behavior, but too few trades for standalone promotion language.
- The new high-frequency families failed:
  - enough trades,
  - not enough edge.

## Reusable Lesson

- On this `USDJPY` feed, the short side does not fail because signals are too rare.
- It fails because the families that create enough trades are mostly reversal/fade constructions, and those edges collapse after actual MT5 costs and stop behavior are applied.
- The current evidence does not support promoting a same-symbol `USDJPY short-only high-frequency` branch into an operational Method2.

## Decision

- Do not call Method2 `operable`.
- Do not integrate any of the new high-frequency short families into the shared EA.
- Keep:
  - `quality12b_guarded` as the only operational mainline,
  - `usdjpy_20260410_method2_s2_short_guarded` as the only surviving short-side research candidate.

## Next Best Move

1. If Method2 must remain `USDJPY short-only`, reopen from a fresh chart thesis rather than another feature-mask fade family.
2. If the business objective is to get a second operational method faster, open Method2 on a different symbol instead of forcing the `USDJPY short` side.
3. If the business objective is turnover inside `USDJPY`, use additional `long-side` sidecars first and stop treating short-side expansion as the shortest path.
