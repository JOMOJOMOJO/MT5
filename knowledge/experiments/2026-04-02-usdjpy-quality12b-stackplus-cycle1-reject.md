# USDJPY quality12b stackplus cycle 1 reject

## Objective

- Increase `quality12b_stack_guarded` turnover without breaking the current live-track quality floor.
- Test whether the old `strict` round-continuation perimeter can be carved out as a third long-only bucket.

## Change

- Extended `usdjpy_20260402_round_continuation_long.mq5` with a third bucket:
  - `round_loose_long`
  - same trend and wick structure as `quality12b`
  - only trades the outer EMA13-distance band:
    - `InpMaxEma13DistancePips < ema13_distance <= InpRoundLooseMaxEma13DistancePips`
  - execution:
    - `stop 18 pips`
    - `target 1.0R`
    - `max hold 12 bars`
- New preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stackplus_guarded.set`

## Actual MT5

- Train `2025-04-01` to `2025-12-31`
  - `net +291.73`
  - `PF 1.14`
  - `139 trades`
  - `max DD 3.32%`
  - run: `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-182706-568992-usdjpy-20260402-round-continuati.json`
- OOS `2026-01-01` to `2026-03-31`
  - `net +124.05`
  - `PF 1.82`
  - `19 trades`
  - `max DD 0.38%`
  - run: `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-182729-204391-usdjpy-20260402-round-continuati.json`

## Comparison vs current stack candidate

- Current promoted turnover sidecar:
  - `quality12b_stack_guarded`
  - train `+372.93 / PF 1.21 / 125 trades / DD 2.80%`
  - OOS `+124.05 / PF 1.82 / 19 trades / DD 0.38%`
- New `stackplus`
  - added train trades (`125 -> 139`)
  - did not add any extra OOS trades (`19 -> 19`)
  - degraded train quality (`PF 1.21 -> 1.14`)

## Verdict

- `reject as promoted candidate`
- The outer `strict` perimeter is not useless, but in this implementation it adds noise on the train window without improving the latest OOS turnover.
- Keep `quality12b_stack_guarded` as the current turnover-biased demo-forward candidate.

## Reusable lesson

- For this USDJPY M15 family, not every train-positive perimeter is worth carrying into the live-track stack.
- If a new bucket does not increase the latest OOS trade count, it must not be allowed to dilute the train PF of the proving candidate.

## Next step

- Explain the current two live candidate entry buckets clearly for manual forward use.
- If more turnover is required, open a genuinely different third bucket or add a short side, instead of widening the current round bucket perimeter again.
