# Rolling 12-Month Validation Ladder

- Date: `2026-04-01`
- Scope: standard repo workflow for evaluating each improved EA on a rolling `12 months = 9 months train + 3 months forward` split

## Default Split

- Total window:
  - latest available `12 months`
- In-sample:
  - oldest `9 months`
- Forward / OOS:
  - latest `3 months`

## Why This Is The Default

- `9 months` is long enough to include multiple market states for parameter search and fixed-parameter validation.
- `3 months` is recent enough to behave like a practical pre-live check.
- The split is simple enough to repeat every time a candidate changes.

## Standard Procedure

1. Lock the candidate EA file and preset.
2. Generate a `train-9m` config and an `oos-3m` config from the base tester config.
3. Use the `train-9m` config for:
   - parameter search
   - fixed-parameter recheck
   - chart review
4. Use the `oos-3m` config for:
   - untouched forward-style MT5 single tests
   - promotion judgement
5. Import both reports into the repo.
6. Do not discuss live promotion without both:
   - a long-window actual MT5 result,
   - and the latest rolling `9m/3m` split result.

## Decision Rule

- If train is good and OOS collapses:
  - do not add small cosmetic filters first
  - question the algorithm shape
- If train and OOS are both good but trade count is still too low:
  - treat the family as quality-first
  - open a separate higher-turnover family
- If train and OOS are both good and live controls preserve the edge:
  - move to demo-forward

## Repo Automation

- Generate the split configs:
  - `powershell -ExecutionPolicy Bypass -File scripts/new-rolling-12m-split.ps1 -BaseConfigPath <1y-config.ini>`
- Then:
  - use `scripts/optimize.ps1` or `scripts/backtest.ps1` on the `train-9m` config,
  - use `scripts/backtest.ps1` on the `oos-3m` config,
  - import both results with `mt5_backtest_tools.py import`.
