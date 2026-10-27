# January loss diagnosis: fixed-source exploratory review

Primary question: do entry-time market context and wave geometry explain January 2025 losses on M5×M1? Broad discovery requested by the user. No new EA run, parameter search, rule adoption or source mutation.

Frozen source tags are in `source_manifest.json`. Three runs stay separate: XAUUSD+ v1.80 (January through Jan30), XAUUSD+ v1.90 (through Jan28), USDJPY v1.80 (Jan1–Mar27). The latest tag name contains v161 but its config declares EA1.80; trust config, not filename. v1.91 only has synthetic execution QA, not strategy results. Gold January is incomplete; USD February is the temporal comparison, March is censored on Mar27. Repeated gold positions across versions are paired observations, not independent samples.

Families to examine before filtering:

1. Accounting: fills/exits, duplicates, censoring, actual net cash/R, long/short, day/month, max loss streak, outsized loss, weekend holding, spread and observable execution drift.
2. H1/H4 closed context: EMA20/50 direction/slope, closed candle direction/body/wick, ATR14 and relative volatility, efficiency ratio12, last24/48-hour position, previous-day range, nearest known earlier H1 swing levels, and existing H1 structure label.
3. W1/W2 and lower execution: fixed wave span/duration, internal reverse path and efficiency, retracement, W2 age, recognition latency, entry room/progress, revision, body/ATR, risk relative ATR, spread/risk, known obstacle and TP extension.
4. Exit diagnosis: actual reason, MFE/MAE bounds between actual entry/exit (M1 Bid proxy), reaching 1R before returning versus immediate adverse move, observed maximum in v190, stop slippage, large gap losses, and paired common entries across gold versions.
5. Robustness: compare January losses with January wins, retain negative/null findings, then describe USD February and partial March without treating them as pristine unseen holdout. Show sample counts. Repeated trades on the same day and correlated feature families reduce independence.

Natural thresholds only: existing H1 labels, alignment signs, location quartiles, ER12<=0.25, existing 5%-of-W1 prior-level band, half-R/1R geometry, known sessions as broker-hour bins (not invented London/Tokyo labels). No threshold sweep or best-PF selection. All exploratory cells are recorded; a selected subgroup's apparent PF is not an executable filtered-EA backtest or proof of positive expectancy.

Clock: timestamps remain broker/source time, UTC offset unverified. H1/H4 features use only complete M5 constituent bars closed and known by entry. No forming hourly candle, no future-confirmed swing. Context warm-up gaps remain missing. Post-entry bars appear only as labeled outcome evidence.

Deliverables: immutable source/hash audit, per-trade feature tables, all-slice tables, specific loss/win chart examples, readable review with ranked mechanisms and one bounded next experiment. Leave EA unchanged until user requests a concrete rule.
