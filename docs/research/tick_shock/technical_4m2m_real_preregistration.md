# January-April learning / May-June locked MT5 test

Registered 2026-09-11 before fitting the corrected monthly real-tick dataset.
Supersedes the wrong-mode intake's prohibition on fitting and tester execution,
under the user's explicit request to build and test an EA.

## Data and boundaries

- Source: `reports/backtest/batches/tstech_real_202501_202506_20260910/202501` through `202506`.
- Read January-April features/outcomes for selection only. May-June outcome files
  must not be opened by selection. Hash/collection QA is not profit evaluation.
- 486 existing causal features; frozen TAIL_V1_PERSISTENT detector, episode rules,
  execution convention and six RR1 distances (0.25/0.5/0.75/1/1.5/2 M5 ATR14),
  minimum three spreads, 900-second maximum hold. No new features or geometry grid.
- Prefix episode and market-cluster IDs by monthly RunId. Purge training labels
  whose entry+900 seconds or observed exit reaches the validation start; whole
  clusters remain outside both sets. Monthly startup/censoring remain explicit.
- Collection-only acceptance of January/April legacy scenario-pool warnings is
  retained, not relabelled global VALIDATED. Generated fallback is separately audited.

## Selection fixed before outcomes

- Use existing fixed SHALLOW_TREE, ELASTICNET_LOGISTIC and LIGHTGBM implementations;
  train Jan-Feb -> March and Jan-March -> April. No randomized splitting.
- Six absolute predicted-net-R cutoffs: -0.1, 0, .05, .1, .2, .3. No quantile fitting.
- One global pending/position, select direction by higher score, exact ties skip.
- Primary stress: additional 0.2 pip round trip beyond observed Bid/Ask spread.
  This is not measured commission. Show 0/.1/.2/.5/1 pip sensitivity.
- Prefer >=200 simulated closed trades in EACH inner-validation month, positive
  net R and PF>1 in both months, aggregate net R positive after removing top five
  profits, positive-day concentration <35%, and adjacent cutoff also positive
  with >=200 trades in each month. Rank qualified candidates by worst monthly EV,
  then aggregate net R, then stable candidate ID. Report all tested cells.
- Refit chosen method/geometry on January-April only; retain absolute threshold.
- Because the user explicitly requests an EA experiment, if no candidate passes,
  freeze ONE diagnostic candidate: prefer the >=200/month subset, then rank by
  worst monthly EV and aggregate net R. If none meets frequency, prioritize the
  largest minimum monthly trade count. Do not call this a positive-edge candidate.
  Do not tune to fix a failure, or select a second EA after May-June results.
- Training fitted profitability is labelled in-sample, never selection evidence.

## EA / final test

- Separate tester-only candidate with fixed risk $10 (not compounding), same
  one-position order adapter. No orders on normal/demo/live charts.
- Build from an isolated copy of the archived collection source dependency tree;
  preserve the two user-deleted includes and old candidate in the original tree.
- Freeze JSON model, generated MQL model, full source/EX5/preset hashes before
  opening held-out outcomes or starting the first May/June tester run.
- Model4, EURUSD M1, six symbols, Bybit-Live environment, $10,000, 1:100,
  May1-Jun1 and Jun1-Jul1 as separate monthly runs. No holdout-based changes.
- Check compile, causal timing, signal parity, order aggregation, observed
  commission/swap/fees, monthly count/EV/PF/DD and independent recalculation.
- May-June is a locked holdout for this experiment, not a claim of universally
  untouched data. No live-readiness or production-profit guarantee.
