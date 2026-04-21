# 2026-04-21 - usdjpy-intraday-feature-regime-research

## Overview

- Task:
  - stop opening new standalone USDJPY intraday families
  - reuse existing telemetry from rejected families
  - identify whether any cross-family feature / regime bundle repeats in OOS and actual
- Scope:
  - `Tokyo-London Session Box`
  - `Local Liquidity Sweep / Failed Acceptance`
  - `External Liquidity Sweep / Failed Acceptance`
  - `N-Wave Third-Leg`
- Verdict:
  - `hard-close` for standalone-family discovery

## Why This Work Happened

- Multiple standalone families already failed for the same structural reason:
  - inventory existed
  - OOS / actual aggregate stayed below `PF 1`
  - better-looking slices were sparse or rescue-dependent
- The next rational step was not another family.
- The next rational step was feature research:
  - isolate time / alignment / trigger / subtype / exit-behavior contributions
  - reject the search entirely if no repeatable bundle survived

## What Changed

- Added cross-family research script:
  - [usdjpy_intraday_feature_regime_research.py](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/plugins/mt5-company/scripts/usdjpy_intraday_feature_regime_research.py)
- The script:
  - reconstructs trade-level outcomes from existing telemetry
  - normalizes family-specific fields into shared research features
  - emits:
    - family aggregate
    - univariate feature tables
    - bivariate feature tables
    - OOS / actual repeatability table
    - acceptance-heavy regimes
    - time-stop-reliant regimes
    - runner-friendly regimes
- Added research review:
  - [2026-04-21-usdjpy-intraday-feature-regime-research-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-intraday-feature-regime-research-review.md)
- Added research summary artifacts:
  - [summary.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-intraday-feature-regime-research/results/summary.md)
  - [results.json](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-intraday-feature-regime-research/results/results.json)

## Evidence

- Analysis script compile:
  - `python -m py_compile plugins/mt5-company/scripts/usdjpy_intraday_feature_regime_research.py`
- Analysis run:
  - `python plugins/mt5-company/scripts/usdjpy_intraday_feature_regime_research.py`
- Supporting prior family reviews:
  - [2026-04-16-usdjpy-liquidity-sweep-failed-acceptance-validation-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-16-usdjpy-liquidity-sweep-failed-acceptance-validation-review.md)
  - [2026-04-16-usdjpy-external-liquidity-sweep-failed-acceptance-validation-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-16-usdjpy-external-liquidity-sweep-failed-acceptance-validation-review.md)
  - [2026-04-20-usdjpy-n-wave-third-leg-validation-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-20-usdjpy-n-wave-third-leg-validation-review.md)
  - [2026-04-21-usdjpy-session-box-regime-diagnostics-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-session-box-regime-diagnostics-review.md)

## Key Decisions

- Did not create a new EA family.
- Did not change entry logic for any rejected family.
- Treated trade telemetry as the source of truth.
- Raised the bar from:
  - `good-looking slice`
  - to:
  - `repeatable OOS / actual feature bundle with enough trades and non-rescue behavior`

## Outcome

- No bivariate feature bundle survived the repeatability gate.
- The only non-sparse repeat was a session-box univariate hint:
  - `entry_session_bucket = tokyo_to_london`
  - OOS:
    - `12 trades / PF 4.54 / net +32.40`
  - actual:
    - `76 trades / PF 1.31 / net +61.23`
- That hint still failed promotion quality:
  - it was not a reusable bundle
  - acceptance exit remained high:
    - `46.05%`
  - runner hit stayed weak:
    - `5.26%`
  - train was still negative

Cross-family failure shapes stayed clear:

- `session_box`:
  - acceptance-back-inside remained the dominant failure
- `local_sweep`:
  - time-stop dependence remained structurally high
- `n_wave`:
  - acceptance-heavy regimes dominated the main subtypes
- `external_sweep`:
  - some runner participation existed, but it never translated into positive expectancy

## Next

- Stop the standalone USDJPY intraday family search for now.
- Do not family-ize the current weak hints.
- If research resumes later, start from a new business hypothesis rather than from these rejected structures.
