# Step 15P Symmetric OCO / Micro-Profit Results

## Verdict

```text
MICRO_PROFIT_FEASIBILITY_NOT_FOUND
DEVELOPMENT_PERIOD_ONLY
PRODUCTION_NOT_ELIGIBLE
```

For the frozen April 2025 population, no tested symmetric OCO geometry had
positive expectancy. This is true before the separate extra-cost stress: all
108 offset x TP x SL cells had negative Bid/Ask-path expectancy, and the upper
bound of every market-cluster bootstrap 95% interval remained below zero.
Adding 0.1 or 0.2 pip therefore cannot create a viable region.

## Formal run

- Period: 2025-04-01 through 2025-05-01, development (not OOS).
- Driver/model: EURUSD M1, real ticks.
- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF.
- Detector: unchanged `TAIL_V1_PERSISTENT`.
- Processed real-tick stream: 14,085,619 ticks.
- Runtime: 31 minutes 20.771 seconds, including preprocessing.
- Tester memory: 624 MB.
- Common-files footprint: 1.101 GiB for this one-month run; the uncompressed
  OCO scenario table alone is 286.98 MB (4.24 MB as deterministic gzip).
- Eligible episode rows: 3,967; existing market-cluster IDs: 3,746.
- OCO scenario rows: 428,436; valid executable outcome rows: 122,184.
- Actual orders/trades: zero.
- Actual round-turn commission across all six symbols: `NOT_OBSERVED`.

The 428,436 rows are repeated geometry outcomes, not independent trades. The
statistical population is 3,967 episodes and, conservatively, 3,746 market
clusters.

The OCO extension keeps at most 16 active episode records per symbol, each with
3 entry-offset legs and 36 TP/SL scenarios. Existing detector storage remains
bounded: the default one-second logical capacity is 904 samples per symbol
(physical compile-time cap 3,612), and old tick history is discarded by the
existing bounded time/capacity policy rather than written tick-by-tick to CSV.
Neither raw ticks nor one-second samples are exported as CSV; only finalized
scenario/event aggregates are emitted.

## Entry offsets

| Offset | Triggered | Long | Short | Ambiguous | No entry | Trades/day |
|---:|---:|---:|---:|---:|---:|---:|
| 0.02 ATR | 481 | 243 | 238 | 3,486 | 0 | 21.86 |
| 0.05 ATR | 941 | 471 | 470 | 3,026 | 0 | 42.77 |
| 0.10 ATR | 1,972 | 999 | 973 | 1,994 | 1 | 89.64 |

Small offsets were frequently already spanned by the live Bid/Ask spread in a
single timestamp group. Those cases were retained as `AMBIGUOUS_TRIGGER`; the
implementation did not choose the favorable side. Triggered Long/Short counts
are close to symmetric and provide no hidden direction rule.

## Highest win-rate geometry

The highest TP-first rate occurred at offset 0.05 ATR, TP 0.02 ATR and SL 1.00
ATR:

- trades: 941
- TP / SL / TIME: 672 / 177 / 92
- TP-first rate: 71.41%
- empirical break-even rate using realized average win/loss: 97.08%
- geometric TP/SL break-even rate: 98.04%
- gross expectancy: -0.2390R
- 0.2-pip stress expectancy: -0.2578R
- gross cluster-bootstrap 95% CI: [-0.2719R, -0.2078R]

Thus the requested 90-99% TP-first region did not appear. The closest tested
high-win cell missed break-even by about 25.7 percentage points and remained
economically negative.

## Least-negative geometry

The least-negative 0.2-pip cell was offset 0.05 ATR, TP 0.15 ATR, SL 1.00 ATR:

| Extra cost | Expectancy (pip) | Expectancy (R) | PF |
|---:|---:|---:|---:|
| 0.0 pip | -2.4111 | -0.2363 | 0.3333 |
| 0.1 pip | -2.5111 | -0.2457 | 0.3135 |
| 0.2 pip | -2.6111 | -0.2550 | 0.2940 |
| 0.5 pip | -2.9111 | -0.2831 | 0.2384 |
| 1.0 pip | -3.4111 | -0.3299 | 0.1553 |

Its gross bootstrap 95% CI was [-0.2725R, -0.2012R], and its 0.2-pip interval
was [-0.2916R, -0.2197R]. Mean gross TP distance was 1.9551 pips while mean
initial spread was 2.1386 pips. The spread diagnostic consumed 109.38% of TP;
spread plus 0.2 pip was 119.61%. Spread is already embedded in the Bid/Ask
outcome and was not subtracted twice.

Even this least-negative geometry was negative for every symbol at 0.2 pip:
AUDUSD -0.3546R, EURUSD -0.2528R, GBPUSD -0.1829R, USDCAD -0.3017R,
USDCHF -0.4480R and USDJPY -0.2232R.

## Surface conclusion

- Gross positive cells: 0 / 108.
- Positive cells after 0.2 pip: 0 / 108.
- Gross bootstrap intervals wholly below zero: 108 / 108.
- Best PF: 0.3469.
- Qualifying adjacent positive regions: 0.
- Offset-level best gross expectancy ranged from -0.2363R to -0.2518R.

The central failure is geometric rather than a lack of frequency. Small TP
distances demand near-perfect hit rates, but the observed maximum was about
71%, and the occasional distant SL plus timeout outcomes dominate. Making the
SL farther raises the required win rate faster than the OCO trigger raises the
observed TP-first rate. Very small TP also sits at or below the spread scale.

## QA and reproducibility

Independent arithmetic reproduced all 108 geometry aggregates. The following
violations were zero: future quote use, entry at/before trigger, barrier at/before
entry, duplicate episode/offset/geometry, market-cluster split, silent ambiguous
direction selection, gross price/pip/R mismatch, and actual order/trade rows.

A separate full MT5 rerun with a different RunId is normalized by removing only
RunId-bearing identifiers and compared field-for-field. Its comparison is stored
with the analysis evidence. Deterministic harness coverage includes Long and
Short triggers, next-quote entry, same-millisecond ambiguity, no-entry timeout,
Bid/Ask barriers, SL gap, 300-second time exit, and three/five-digit pip size.
The existing regression suite also remained green: 407 PASS, 0 FAIL, 0 XFAIL,
0 XPASS, 9 reasoned SKIP, and 0 BLOCKED. The dedicated OCO harness passed 16/16.

## Evidence

- [Formal run](../../../reports/backtest/runs/20260908_ts15p_symmetric_oco_micro_profit_202504/)
- [Geometry surface](../../../reports/analysis/tick_shock/step15p/geometry_surface.csv)
- [Cost sensitivity](../../../reports/analysis/tick_shock/step15p/cost_sensitivity.csv)
- [Independent recalculation](../../../reports/analysis/tick_shock/step15p/independent_recalculation.csv)
- [QA checks](../../../reports/analysis/tick_shock/step15p/qa_checks.csv)
- [Validation summary](../../../reports/tests/tick_shock/step15p_validation_summary.md)
- [Net expectancy heatmap](../../../reports/analysis/tick_shock/step15p/tp_sl_net_expectancy_heatmap.png)
- [Win-rate heatmap](../../../reports/analysis/tick_shock/step15p/tp_sl_win_rate_heatmap.png)
- [Trade-frequency heatmap](../../../reports/analysis/tick_shock/step15p/tp_sl_trade_frequency_heatmap.png)
- [Cost curve](../../../reports/analysis/tick_shock/step15p/cost_vs_expectancy.png)
- [TP cost-consumption curve](../../../reports/analysis/tick_shock/step15p/tp_distance_vs_cost_consumed_ratio.png)

No finer April grid, direction filter, lot sizing, OOS claim or production
promotion is justified by this result.
