# USDJPY Regime Buckets Cycle 1 Kill

## Summary

- Family: `usdjpy_20260402_regime_buckets`
- Objective: `high_turnover_compounding`
- Window: rolling `9 months train / 3 months OOS`
- Verdict: `kill`

This fresh family produced enough trades to be worth a serious cycle, but it failed on both quality and objective fit after actual MT5 validation.

## Baseline

- Baseline train: `net -807.88 / PF 0.84 / DD 11.32% / 212 trades`
- Baseline OOS: `net -1164.34 / PF 0.47 / DD 11.64% / 82 trades`

## Side Split

- Long-only train: `net -1184.77 / PF 0.47 / DD 11.85% / 94 trades`
- Long-only OOS: `net -266.31 / PF 0.90 / DD 7.71% / 112 trades`
- Short-only train: `net -724.16 / PF 0.85 / DD 11.93% / 202 trades`
- Short-only OOS: `net -1180.96 / PF 0.37 / DD 11.81% / 69 trades`

## Long Bucket Split

- Long1-only train: `net -1172.00 / PF 0.53 / DD 11.88% / 101 trades`
- Long1-only OOS: `net -49.81 / PF 0.94 / DD 3.90% / 36 trades`
- Long2-only train: `net -1184.77 / PF 0.47 / DD 11.85% / 94 trades`
- Long2-only OOS: `net -266.31 / PF 0.90 / DD 7.71% / 112 trades`

## Quality Probe

- `long-only + NY session + max spread 1.5` train: `net -810.62 / PF 0.43 / DD 9.19% / 57 trades`
- `long-only + NY session + max spread 1.5` OOS: `0 trades`

## Reusable Lessons

- The short side is clearly harmful on this construction and should not be carried into the next family.
- `long2` supplies turnover, but not enough edge after actual MT5 friction.
- `long1` is the least-bad long branch on OOS quality, but it is too sparse and still loses on train.
- The feature-lab hint `NY + low spread` did not survive direct translation; it killed the sample instead of lifting the edge.
- This family is structurally closer to a noisy reversal basket than to the CEO-requested `EMA13 / EMA100 + Dow + round-number + volatility` doctrine.

## Next Step

Open the next USDJPY family from a fresh thesis based on:

- `50 pip zone escape`
- `round-number breakout / rejection`
- `EMA13 / EMA100 continuation`
- explicit volatility-state gating

Do not spend another immediate cycle on `regime_buckets`.
