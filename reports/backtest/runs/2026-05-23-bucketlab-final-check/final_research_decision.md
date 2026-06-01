# ExpectedValue LongOnly BucketLab Final Research Decision

Date: 2026-05-23

## Decision

Do not promote `ExpectedValue_LongOnly_BucketLab` to demo or live.

Archive it as a research asset.

## Why It Is Not A Production Candidate

The best 2025 variants are profitable and non-ruinous, but the family does not yet survive the validation question that matters most:

- v2.5 2025: `76` trades, ExpectancyR `+0.2612R`, PF `1.9043`, MaxDD `8.21%`, max losses `3`
- v2.5 2026 Jan-Apr OOS diagnostic: `1` trade, ExpectancyR `-1.0R`, PF `0.0`

The OOS failure is not a catastrophic drawdown. It is a regime-transfer failure: the strategy almost stops trading. A live candidate cannot rely on a 2025-only market state.

## Why It Should Not Go To Demo Or Live

- OOS trade count is too low to support live-readiness.
- The apparent 2025 quality is concentrated in a family of expansion/shallow continuation states that did not appear often enough in the OOS window.
- New final-check directions did not create a robust additional source of trades.
- Longer-hold variants increased loss-streak stress.
- M5 swing SL suppressed activity too much.
- The new `MID_RANGE_CONTINUATION` bucket had only one trade and negative R.
- No final-check variant justified a fresh OOS run without risking OOS overfitting.

## Why It Is Worth Keeping

The project produced useful reusable infrastructure:

- robust fixed-lot and risk-percent sizing path for small capital tests
- margin checks and total risk checks
- daily, weekly, drawdown, and loss-streak stop logic
- no averaging and no martingale controls
- second-entry quality gating
- bucket-level logging
- candidate score logging
- near-miss diagnostics
- monthly, bucket, exit reason, and relative-metric analysis artifacts

This is now a useful BucketLab framework, even though the current long-only family is not live-ready.

## What To Keep

Keep as research assets:

- `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- v2.5 presets
- final-check presets
- candidate_v1 archive
- all 2025 and OOS summaries
- near-miss diagnostic outputs
- final-check result CSVs

Do not treat any final-check preset as production.

## Best Restart Direction

Priority 1: start a new market-state family from bar-data/statistical discovery, not from additional threshold edits to the current buckets.

Most promising direction:

- a longer-hold continuation family that uses M5/M15 structure more directly
- M1 can remain execution, but the trade thesis should be M5/M15 continuation rather than M1 scalping
- use OOS only after a candidate is fixed from a fresh development slice

Priority 2:

- design a separate short-side BucketLab, but do not merge it with the production short EA until it has its own fixed validation evidence.

Priority 3:

- keep current second-entry gate if this long family is revisited; do not return to raw two-position stacking.

## Kill Criteria For This Family

If future research still cannot produce:

- at least moderate trade count across multiple years,
- positive expectancy outside one market regime,
- no loss-streak or drawdown stress,
- and no dependence on OOS threshold tuning,

then the current long-only USDJPY M1 scalper family should be parked permanently.

