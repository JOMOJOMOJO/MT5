# Independent H1 ER12 definition review

Reviewed 2026-10-27 (Japan date). Read-only review of the frozen January diagnosis; no EA change or tester launch.

## Verdict

The mathematical formula and indexing in `tools/wave33_visual/january_higher_tf.py` are correct for Kaufman's close-price Efficiency Ratio over 12 changes. It is an appropriate **single diagnostic of net directional progress relative to the close-price path**, but is not an exact count of market oscillations, a double-top detector, or a trend-direction filter.

The most important implementation issue found is the **binary floating-point threshold boundary**: an exact mathematical ER of 0.25 can evaluate as 0.2500000000000007, and the existing `<= .25` comparison then classifies it on the wrong side. This does not change any of the 129 available frozen entry classifications, but must be addressed in a deterministic comparison implementation and tested.

A separate, material portability limitation is that the frozen feature uses only H1 bins containing **all 12 expected M5 bars**. This is not necessarily the same series as the broker's native H1 bars. In particular, a session shortened by a holiday can produce a valid native H1 bar with fewer M5 bars. Native H1 parity has not been established.

## Exact definition

At the decision time, let `C[0] ... C[12]` be 13 eligible, observed, completed H1 closing prices, oldest to newest:

```
path = sum(abs(C[i] - C[i-1]) for i in 1..12)
net = abs(C[12] - C[0])
ER12 = net / path                    # if path > 0
cancelled_path_fraction = 1 - ER12
```

The window is **12 closing-price changes and 13 closes**, not 12 closes. The first close occurs one hour after its H1 bar's opening timestamp. When there are session gaps, it is not necessarily 12 elapsed calendar hours.

The implementation's indexing is correct: `closes[-13]` through `closes[-1]`; the denominator's range starts at `len(closes)-12`, comparing each element to its predecessor, so it contains exactly 12 differences.

For finite input prices and a positive denominator, the triangle inequality proves `0 <= ER12 <= 1`. Upward and downward trends have identical ER if their path shape is the same. Monotone movement gives 1; return to the original close gives 0.

If a Japanese label called 往復度 is displayed, the unambiguous choice is **往復度 = 1 - ER12** (large means more cancellation). Keep ER12 in the CSV as well. The proposed old low-efficiency condition `ER12 <= 0.25` is equivalent to `往復度 >= 0.75`. Avoid calling ER itself a quantity that increases with oscillation.

Interpretation of 0.75: 75% of the total close-to-close path is cancelled by movement in the opposite direction. It does **not** mean that 75% of candles reverse, that 75% of the time is sideways, or that the probability of a losing trade is 75%.

More precisely, if `U` and `D` are total upward and downward close-distance, then `ER = abs(U-D)/(U+D)` and `1-ER = 2*min(U,D)/(U+D)`. The smaller directional component at ER 0.25 accounts for 37.5% of total travelled distance, not 75%.

## Independent checks performed

The review imported the frozen script and exercised its actual `bar_features()` implementation, rather than only reimplementing the formula.

| Fixture | Expected ER | Observed | Finding |
|---|---:|---:|---|
| 13 monotone increasing closes, 100 through 112 | 1 | 1 | PASS |
| 13 monotone decreasing closes, 112 through 100 | 1 | 1 | PASS |
| 13 alternating closes, 100/101, ending at 100 | 0 | 0 | PASS |
| One smooth up-and-back path, 100 to 106 to 100 | 0 | 0 | PASS; important semantic limitation |
| Mixed path with net 5.4 and path 12.6 | 5.4/12.6 | 0.4285714285714292 | PASS within numerical precision |
| 13 identical closes | Undefined (0/0) | None | PASS; do not silently map to zero |
| Only 12 closes | Insufficient history | Missing ER | PASS |
| Nine changes of +1 followed by three changes of -1.8 | Exactly 0.25 | 0.2500000000000007 | Formula numerically normal; threshold classification FAIL |

The boundary fixture has upward distance 9, downward distance 5.4, path 14.4 and net 3.6. Its mathematical ratio is exactly 0.25. Use decimal/tick-based arithmetic in the frozen comparison, or an explicitly documented tiny arithmetic tolerance in native code; do not tune an economic threshold to fix arithmetic. Include exact, just-below and just-above boundary fixtures. A floating-point clamp should not conceal materially invalid values.

The frozen `htf/features.csv` contains 131 entries and 129 windows with 13 closes. Independent `Decimal` recalculation from each saved 13-close string found:

- 0 formula mismatches larger than `1e-12`;
- 0 classifications differing from exact decimal `ER <= 0.25`;
- 0 available ER values outside [0,1];
- 0 zero-path denominators in available entry windows;
- the nearest observed ER to the threshold is 0.250498338870439, over 0.000498 away, so the new boundary finding does not explain the old sample results.

## Decision-time causality audit

The old report describes context at actual FILL, which is acceptable as a descriptive feature. A tradable entry filter must use the information available **before the entry request**, not a bar that becomes available during order latency.

Independent recalculation selected aggregates with both `end <= decision_at` and `known <= decision_at` at SIGNAL-known, ORDER and FILL timestamps. In these frozen files:

| Source | Entries | ER available | SIGNAL vs ORDER window/ER differences | ORDER vs FILL window/ER differences | Largest order-to-fill delay |
|---|---:|---:|---:|---:|---:|
| gold_v180 | 28 | 27 | 0 | 0 | 18 seconds |
| gold_v190 | 23 | 22 | 0 | 0 | 18 seconds |
| usd_v180 | 80 | 80 | 0 | 0 | 18 seconds |

Thus there is no observed order/fill lookahead difference in the current frozen sample. This is sample-specific evidence, not permission to implement the filter at FILL.

The production closed-bar batch sorter processes equal-close-time frames in descending timeframe order; an H1 update at an hour boundary precedes its M1 signal. A future filter must consume that accepted H1 state, or explicitly use a pre-order historical query with an availability rule. Timestamp equality alone does not prove event sequencing in arbitrary future code.

## Missing bars, sessions and native parity

The current aggregator groups broker-clock M5 opening times on the whole-hour grid and requires exactly all 12 M5 slots. It sets H1 known time to the maximum constituent known time and does not forward-fill absent hours. It selects only closed and already-known bins. These are conservative and causal choices.

However, completeness of a grid and existence of a valid native H1 candle are different concepts:

- Gold `2025.01.20 21:00` contains six observed M5 bars through 21:25 and is omitted from both gold H1 series. The last M5 bar becomes known at `2025.01.21 01:00:03`. The record alone does not prove whether the cause is the trading session or missing observations.
- This omitted hour is not inside any of the 13-close windows used by the frozen gold entry features, so it does not currently explain their low-ER classifications.
- The first `2024.12.31 23:00` hour is a one-M5 startup fragment and is appropriately not treated as a complete historical H1 hour. Current tail fragments must also stay unavailable.
- Fully absent session hours are not invented. The 13 observed closes can nevertheless span a daily, weekend or holiday gap.
- Entry windows crossing at least one non-one-hour source-bar interval number 9/27 for gold_v180, 8/22 for gold_v190 and 9/80 for usd_v180: **26 of 129 available windows**. These are not 26 independent discoveries because gold versions overlap.
- The last eligible H1 close is less than one hour old at every frozen entry (maximum 0.855h, 0.852h and 0.969h respectively). Constituent known delays can be about two days around market closure; the explicit known-time condition correctly delays their use.

In a fixed frozen screen, retain the old aggregation convention and clearly name it `observed_complete_m5_H1_proxy`. Do not silently replace it halfway through the comparison. Before native adoption, compare exact 13 closing prices, their timestamps and ER from `CopyRates(PERIOD_H1, ...)` against the proxy, including a normal hour, daily reopen, weekend reopen, the partial Jan20 hour and the dataset start. If parity fails, report it and use one explicitly versioned series definition in both arms. Do not assume a native bar with fewer constituent M5 observations is invalid merely because the strict-grid proxy rejected it.

## What this quantity does not measure

- **Repeated versus single reversal:** 12 alternating steps and one large V-shaped reversal can both give ER=0. Low ER does not prove repeated small chops.
- **Intrabar wick action:** hourly closes can move monotonically while every candle has a huge upper/lower wick. ER can be 1 despite considerable intrahour two-way movement. The fixtures deliberately allow large high/low ranges without changing ER.
- **Direction relative to the trade:** a strong H1 uptrend and downtrend both give high ER; the quantity alone does not veto a short against an upward H1 trend.
- **Amplitude or costs:** a tiny monotone path can give ER=1 while spread is larger than the tradable range. A large price excursion can give ER=0. It is not a volatility or spread adequacy measure.
- **Trend starts and V-turns:** a just-starting trend can still have low ER because its preceding return journey remains in the 12-change window. Conversely, one old gap can dominate a high ER reading. This is a causal lag and construction effect, not an implementation error.
- **Double top/bottom, level survival or future profitability:** those require additional definitions and validation. They must not be inferred directly from this one quantity.

The requested single comparison should not quietly add wick, direction, volatility, gap or structure conditions to patch these blind spots. Record them as limitations and keep this experiment one-dimensional.

## Single-comparison recommendation

1. First complete one **fixed-entry OFF versus ON screen** using the saved actual entries and their original exit policy/cost/R ledger. OFF retains all original entries; ON removes only known, valid `ER12 <= 0.25`. Missing ER remains explicitly counted and unchanged in both arms so that a warmup/missing-data filter is not added as a second change. Keep sources/versions and months/directions separate.
2. Recompute ER at pre-order availability; verify it against the saved FILL feature without using later outcomes. Record all removed wins and losses, not only avoided losers, trade/day counts, mean/sum R, cash PF, retained original sequence loss streak and concentration by day. Sequence figures are those of the retained fixed-entry sample, not a rerun's account trajectory.
3. Keep `N=12` and threshold 0.25 exactly as already exposed in the January exploratory review. Neither setting is optimized in this comparison. The threshold was one of 18 examined features in the previous broad diagnosis; it is therefore **discovery-informed, not an unseen preregistered proof**.
4. January gold is incomplete, early warmup has missing ER, repeated gold versions are correlated, and USD February already supplies a sign reversal. Do not suppress that counterexample or call February pristine OOS after it has been viewed.
5. This inexpensive fixed-entry comparison should precede a native current-v1.91 A/B. Old v1.80/v1.90 outcomes cannot establish v1.91 partial-exit profitability. If the fixed mechanism is inconsistent across already available strata, stop rather than fund a current-EA real-tick run to rescue it. If a later native comparison is justified, keep current v1.91 exits and every non-ER input identical in both arms, and independently verify native H1 series semantics.

The frozen screen is not an executable account backtest: skipping trades can change position availability, balance-based sizing, opposing-wave state and future candidate accounting. It can reject a weak mechanism cheaply, but cannot by itself promote a profitable EA.

## Primary technical source

MetaQuotes' [Adaptive Moving Average documentation](https://www.mql5.com/en/code/10) defines ER as absolute N-period price displacement divided by the sum of N absolute one-period changes, approaching 1 for directed movement and 0 for a path with little net progress. The [iAMA reference](https://www.mql5.com/en/docs/indicators/iama) identifies the AMA calculation period as the efficiency-coefficient period. These support the formula; they do not establish 12 or 0.25 as a profitable filter setting.

## Reviewed local evidence

- `tools/wave33_visual/january_higher_tf.py`, especially `bar_features`, `aggregate`, `THRESHOLDS` and `process_run`.
- `reports/backtest/analysis/wave33_january_20261026/PLAN.md`.
- `reports/backtest/analysis/wave33_january_20261026/htf/features.csv` and `availability.json`.
- Frozen `source/{gold_v180,gold_v190,usd_v180}/{upper_bars.csv,events.csv}`.
- `mql/Include/Wave33Visual/BarOrder.mqh` and current v1.91 `FeedClosed` ordering, read only.

## Follow-up integration review: v1.92 native comparison

The root agent elected to perform one bounded January 2025 Gold native OFF/ON comparison after the saved-entry screen, as an explicit user-requested diagnostic rather than a strategy promotion. This is a narrower engineering comparison of the current v1.91 exit policy with one H1 veto; it does not erase the mixed historical evidence above or establish a universal filter.

Reviewed read-only:

- new `mql/Experts/Wave33H1EfficiencyVerifier.mq5` against `Wave33DayTradePartialVerifier.mq5` with an exact file diff;
- `H1Efficiency.mqh`, `H1EfficiencyExecution.mqh`, `H1EfficiencyTests.mqh`;
- the existing `FinishUnordered()` implementation and CSV escaping helper.

No blocking integration defect was found in this snapshot. Findings:

1. **Scope:** The new source clones v1.91 and changes version/magic/tag, adds the H1 module and one bool input, config/hash fields, logging and lifecycle hooks. The diff leaves the existing order-size calculation, half-profit policy, step-SL policy, opposite-wave exit and time exits intact. This diff is not itself a protected-source hash audit; the launch owner should retain that independent evidence.
2. **Native series definition:** `CopyRates(_Symbol, PERIOD_H1, 1, 13, rates)` requests 13 native bars before the current bar; `ArraySetAsSeries(false)` gives oldest-to-newest indexing. All input opening times are validated as ordered, hour-aligned and at least one full hour before `TimeCurrent()`. Native broker history preceding tester start may be used, explicitly differing from the old prospective M5-only sample. Config identifies this measurement version instead of claiming parity.
3. **Pre-order causality:** H1 is read inside `HandleSignal`, using the current decision tick, before `OrderCheck`, `MarkOrderSubmitted` and `OrderSend`. There is no FILL-dependent eligibility, completed-hour rewind, or forming-H1 close in the decision. Closed-bar ordering continues to process larger frames before smaller frames at equal close time.
4. **Predicate and missingness:** The only new veto is enabled + valid + `ER <= 0.25 + 1e-12`. The numeric epsilon repairs the independently observed decimal boundary. Flat, missing, invalid and future data remain explicitly unavailable/allowed, and session gaps are logged without another veto.
5. **Existing precedence and lane release:** Old chop, prior-context and structural/risk failures retain priority. H1 rejection happens before submitting an order and calls the guarded `FinishUnordered()` API. The API rejects an already-submitted/open/untriggered setup. A release failure is logged and still cannot submit the rejected order.
6. **Diagnostic precedence limit:** `precedence=ELIGIBLE` currently means only that chop, prior context and `Plan()` passed. The H1 check precedes tester/weekend/position-busy/trade-mode/lot-size/order-check guards. Therefore an H1 `SKIP` is not automatically an avoided trade that OFF would have filled. Post-run comparison must distinguish all H1 skips from the paired OFF filled entries, and acknowledge newly available candidates after lane release. This is a reporting caveat, not a reason to add another strategy condition.
7. **CSV:** Text fields that can contain a quote/delimiter use the existing `ScaleCSV()` helper, which doubles embedded quotes and wraps the whole value in quotes. Numeric fields and timestamps have no delimiter content. Both bool arms emit the same feature schema. Native execution must still verify actual row parsing/column counts; static inspection alone is not a runtime CSV proof.
8. **Embedded tests:** Both tester arms execute the same pure-policy checks in `OnInit` before the source becomes ready or reaches order handling. Tests include 13/12 indexing, positive/negative directions, the V-turn counterexample, mathematical and decimal threshold boundaries, affine invariance, gaps, forming/future bars, missing/mismatched arrays, flat prices, bad prices and non-finite values. A failed test causes initialization failure. These test bodies were inspected; their native PASS result was not claimed before an actual run.
9. **Old artifacts:** No source or binary was changed by this review, and no tester was launched by this reviewer. Existing shared execution headers were only read. The root agent remains responsible for compilation, source protection hashes, one-variable preset equality and the explicit stop immediately after its launch.

The bounded native comparison should be reported as `NATIVE_H1_CLOSED_ER12_025_V1`, separately from `observed_complete_m5_H1_proxy`. Even if January ON improves, adoption must remain unresolved until account totals, costs, original sample counts, activity loss, entry-day concentration and the known non-January counterexamples are evaluated.
