# H1 / M15 context research — frozen protocol

## Scope and windows (fixed before viewing context outcomes)

Separate tester-only recorder and analysis. Production EA, Shared, and previous feature recorder remain unchanged. No orders, threshold optimization, or AND search.

First check March 3–8 2025. Compare the previous January–March (discovery) and May–July (replication) windows. Nine regime cells per stage will likely be sparse: if any cell has fewer than 30 primary candidates in either window, extend once by the fixed August–October 2025 window. Report the extension separately, regardless of outcome; do not keep extending until positive. Previously studied windows are not pristine OOS.

## Causal context definition

- H1 = broad background; M15 = direct parent of M5. Classify independently.
- Strict confirmed 2-left / 2-right pivots on CLOSED bars only. Equal high/low disqualifies the pivot. This is a separate environment descriptor, not a modification to Shared pivot rules.
- UP: latest two confirmed highs and latest two confirmed lows both increase. DOWN: both decrease. RANGE: mixed/equal changes. Fewer than two of each = UNKNOWN, never force to RANGE.
- Regime is a confirmed swing descriptor, not a claim that a new intrabar reversal is already known. Record all four pivot prices, bar times, and confirmation times.
- Confirmation time = last right confirmation bar open + timeframe seconds. Use only timestamps <= signal time. CopyRates excludes the forming bar. Closed-bar history: 800 bars per context TF.
- Position = (entry Ask - latest confirmed low)/(latest confirmed high - latest confirmed low). Do not clip outside [0,1]. Nonpositive denominator -> missing with explicit status.
- Overhead room R = (latest confirmed high - entry Ask)/candidate risk distance, for each SL basis. Keep negative values (that high has already been exceeded); do not silently substitute a future/higher resistance.
- Auxiliary native EMA20 slope = (last closed EMA - EMA three closed bars earlier)/(3*last closed ATR14). Record values and timestamps. Not a filter.

## Unchanged outcomes and candidate selection

Reuse previous first CHoCH / first HL / READY per parent + M1 attempt + stage, RR1, 10-point SL buffer, Ask entry/Bid exit, 240-minute maximum shadow holding time, 60-minute MFE/MAE. STAGE SL is primary; REVERSAL_CONTROL is sensitivity analysis. Keep future outcome labels separate from causal context. Fees, swap and added latency/slippage remain unmodelled; no portfolio return claim.

## Execution opportunity accounting

Each stage is a separate strategy stream, never add CHoCH+HL+READY counts. Sort by entry tick, then most recent M5 parent, then deterministic ID. Only one open position; next entry must be at or after BOTH prior exit and prior ENTRY +15 minutes. Cooldown begins at fill, not exit. Enforce one filled trade per M5 parent across all its M1 attempts. An end-censored position remains occupied through the window end.

Report (a) all-candidate unfiltered chronological replay then attribute accepted entries to context, and (b) each one of the nine regime cells replayed alone as a hypothetical capacity estimate. (b) is not a deployed filter or optimized combination. Keep rejection reasons and accepted IDs. Missing context remains in the unfiltered stream and is reported separately.

## Descriptive statistics and integrity

All nine H1×M15 cells, including zero-count cells, plus UNKNOWN. For each stage/basis/period: N, parents, unique decision times, win rate, mean R, fixed-seed parent-cluster 95% bootstrap intervals, MFE/MAE to exit and at 60 min, monthly raw and executable counts (zero months included), timeouts/censors. Merge parent clusters sharing a single M1 attempt.

Compare cell mean minus stage mean across windows; report dispersion and small samples rather than selecting the best point estimate. Predefined position buckets: below low, 0–0.5, 0.5–1, above high. Room buckets: <=0, (0,1), [1,2), >=2 R. EMA slope signs only. No data-derived thresholds or conjunction search.

Verify old candidate/outcome CSV parity on overlapping windows, no future confirmed pivots, strict pivot behavior using deterministic fixtures and independent calculation, clean native compile, repeat-run byte equality, and production hashes. Re-audit M1 time gaps in any extended window. Save summary.md, machine-readable evidence, and a short devlog.
