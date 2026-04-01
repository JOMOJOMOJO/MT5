# USDJPY Golden Method Flexible-Risk Rerun

## Thesis

- Re-run the active `USDJPY Golden Method` baseline after relaxing the original illustration rules:
  - fixed `10 pip / 10 pip` is no longer mandatory,
  - target is now `1.2R`,
  - micro-cap risk override is allowed for the first `100 USD` stage,
  - `1 trade/day` is the minimum operating target and `2+` is preferred.

## Evidence

- EA: `mql/Experts/usdjpy_20260402_golden_method.mq5`
- Preset: `reports/presets/usdjpy_20260402_golden_method-baseline.set`
- Train run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-010923-010657-usdjpy-20260402-golden-method-tr.json`
  - `net -8045.98 / PF 0.78 / 531 trades / DD 86.80%`
- OOS run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-010922-915506-usdjpy-20260402-golden-method-oo.json`
  - `net -4635.25 / PF 0.58 / 111 trades / DD 50.66%`

## What Changed

- `10 pip` fixed take-profit was removed from the baseline preset.
- The baseline now uses `1.2R` target logic.
- Micro-cap override is enabled for balances up to `150 USD`:
  - mature reference risk remains `2%`,
  - micro-cap override risk is `3%`,
  - daily hard-loss cap remains active.
- Max trades per day was widened to `3`.

## What We Learned

- Flexible exits by themselves do not rescue the baseline.
- The rerun increased turnover sharply:
  - train `192 -> 531 trades`,
  - OOS `52 -> 111 trades`.
- The extra turnover came from weaker setup acceptance, not from a stronger edge.
- So the current failure is not "take-profit too tight" or "2% rule too strict".
- The current failure is still entry quality:
  - follow-through phase is not isolated well enough,
  - the system still trades profit-taking / noisy pullback states,
  - Strategy 2 still accepts too much round-number chop.

## Practical Decision

- Verdict: `still baseline reject`
- Keep `USDJPY Golden Method` as the active mainline family.
- Do not promote the new flexible-risk preset.
- Do not chase the daily trade-count target by loosening entries.
- Treat `1/day` as an outcome target, not as permission to overtrade weak setups.

## Next Cycle

1. Tighten Strategy 1 around true follow-through:
   - stronger Dow swing continuation test,
   - explicit `V-shape` requirement,
   - reject slow grindbacks into EMA13.
2. Rebuild Strategy 2 as anti-chop breakout logic:
   - stronger large-candle definition,
   - repeated round-touch rejection,
   - post-break follow-through confirmation before EMA13 retest entries.
3. Add explicit volatility-state blocking before entry:
   - avoid repeated `50 pip` zone churn,
   - prefer large range / large movement states.
4. Use feature mining on `USDJPY` to confirm whether the doctrine-aligned follow-through state has a measurable edge before more parameter tuning.
