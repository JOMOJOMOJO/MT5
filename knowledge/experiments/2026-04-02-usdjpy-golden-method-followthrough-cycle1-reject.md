# USDJPY Golden Method Follow-Through Cycle 1 Reject

## Thesis

- Stop treating the failing `USDJPY Golden Method` baseline as one opaque block.
- Split the family into:
  - `Strategy 1 / Strategy 2`,
  - `buy / sell`,
  - then test the least-bad branch with a feature-informed pullback-quality filter.
- Use actual MT5 evidence on the repo-standard `9 months train / 3 months OOS` ladder.

## Changes In This Cycle

- Added direction-level diagnostic toggles to the EA:
  - `InpAllowLongs`,
  - `InpAllowShorts`.
- Created diagnostic variants for:
  - `S1 buy-only`,
  - `S1 sell-only`,
  - `S2 buy-only`,
  - `S2 sell-only`.
- Added an optional `Strategy 1` pullback-quality filter using `Stochastic %D`:
  - `InpUseStrategy1StochFilter`,
  - `InpS1BuyMaxStochD`,
  - `InpS1SellMinStochD`.
- Tested `S1 sell-only` with `stoch75` and `stoch82` as feature-informed overbought qualifiers.

## Evidence

### 3-Month OOS (`2026-01-01` -> `2026-04-01`)

- `S1 buy-only`
  - `net -952.42 / PF 0.20 / 7 trades / DD 11.64%`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-013434-461108-usdjpy-20260402-golden-method-s1.json`
- `S1 sell-only`
  - `net +32.32 / PF 1.15 / 2 trades / DD 2.06%`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-013434-960657-usdjpy-20260402-golden-method-s1.json`
- `S2 buy-only`
  - `net 0.00 / PF n/a / 0 trades`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-013435-463826-usdjpy-20260402-golden-method-s2.json`
- `S2 sell-only`
  - `net 0.00 / PF n/a / 0 trades`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-013436-014699-usdjpy-20260402-golden-method-s2.json`

### 9-Month Train (`2025-04-01` -> `2025-12-31`)

- `S1 sell-only`
  - `net -1153.11 / PF 0.54 / 19 trades / DD 15.88%`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-013523-383490-usdjpy-20260402-golden-method-s1.json`

### OOS Retry With Feature-Informed Pullback Qualifier

- `S1 sell-only + stoch75`
  - `0 trades`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-013805-229688-usdjpy-20260402-golden-method-s1.json`
- `S1 sell-only + stoch82`
  - `0 trades`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-013805-771132-usdjpy-20260402-golden-method-s1.json`

## What We Learned

- `Strategy 2` is not just weak; in its current mechanical form it does not trigger enough to matter.
- `Strategy 1 buy-only` is actively harmful on the latest OOS slice.
- `Strategy 1 sell-only` is the least-bad branch, but the train slice is still clearly negative.
- The first feature-lab-informed `stoch D` qualifier was too strict:
  - it removed the already tiny OOS sample completely,
  - so the branch did not become more reliable, it just stopped trading.
- This means the next improvement should not be another generic tightening pass.

## Decision

- Verdict: `follow-through cycle 1 reject`
- Keep `usdjpy_20260402_golden_method` as the active mainline family for now.
- Kill `Strategy 2` as a promotion path in its current form.
- Kill `Strategy 1 buy-only` as a near-term promotion path.
- Keep `Strategy 1 sell-only` as the only surviving research branch, but do not treat it as a candidate yet.
- Reject the first `stoch D` pullback qualifier as too restrictive at current thresholds.

## Next Cycle

1. Run a dedicated `S1 sell-only` event study by session and shape quality:
   - London vs New York,
   - sharper `V-shape` vs slower grindback,
   - transition-line distance before entry.
2. Rebuild `Strategy 2` only if a fresh round-number / breakout event study shows real signal on `USDJPY`.
3. Stop using family-level aggregate results alone; treat `S1 sell-only` as the only branch worth detailed diagnosis.
