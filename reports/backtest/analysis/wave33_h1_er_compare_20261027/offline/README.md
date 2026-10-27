# H1 ER12 fixed saved-entry screen

ER12 <= 0.25 only; no threshold/period grid, EA changes, or MT5 launch.

ORDER-time features independently reconstructed from frozen M5 bars. Missing history or zero path allows the original entry with explicit missing status. Native saved outcome R always uses original risk, never trailed SL.

| Run / entry month | OFF n / net R / PF cash | ON n / net R / PF cash | Skipped win / loss / flat | Delta R | Missing allowed |
|---|---:|---:|---:|---:|---:|
| gold_v180 / 2025-01 | 28 / -9.707 / 0.506 | 16 / -5.191 / 0.493 | 3 / 9 / 0 | +4.517 | 1 |
| gold_v190 / 2025-01 | 23 / -9.499 / 0.445 | 13 / -2.312 / 0.736 | 1 / 9 / 0 | +7.187 | 1 |
| usd_v180 / 2025-01 | 32 / -9.794 / 0.582 | 19 / 1.217 / 1.134 | 2 / 11 / 0 | +11.011 | 0 |
| usd_v180 / 2025-02 | 18 / -0.733 / 0.924 | 11 / -1.160 / 0.821 | 4 / 3 / 0 | -0.427 | 0 |
| usd_v180 / 2025-03 | 30 / -1.973 / 0.858 | 15 / 3.049 / 1.527 | 5 / 10 / 0 | +5.022 | 0 |

## Honest accounting and limits

- The denominator of per-original-entry R remains the OFF count: skipped trades contribute zero. Executed-trade averages are also exported but not used as the sole improvement claim.
- Versions share trades and exit differently. Each version/month remains a separate cell. No pooled net R or claimed 131 independent opportunities.
- ON removes saved trades only. It cannot discover replacement candidates, changed lane availability, opposite-wave exits influenced by screening, new fills, changed lot sizes, or equity compounding. Saved-cash PF is conditional accounting, not native filtered-EA PF.
- The original-money-risk denominator is verified against native net cash for all 131 entries. Ledger records allow one FILL and EXIT per setup; duplicates or unclosed positions fail rather than silently disappear.
- H1 bars require every scheduled five-minute grid slot. ER uses 13 completed observed H1 closes / 12 differences; it is not automatically 12 elapsed wall-clock hours. Window gaps/spans are exported. Missing complete bins are not forward-filled.
- Entry-day paired bootstrap (10,000, fixed seed) and leave-one-entry-day-out retain within-day correlation. They do not solve temporal dependence, regime shift, multiple prior exploratory screens, or the tiny number of day clusters. Bootstrap fractions are descriptive, not confirmatory p-values.
- Exposure proxies count every frozen open position as one original-R slot throughout holding. They do not revalue current trailed risk, correlation, margin, minimum lot, currency conversion, or live portfolio survival. Cash totals are not an equal-risk sizing simulation.
- Gold January stops before month-end. USD March is censored at March27. USD February/March were already inspected in the prior broad analysis and are temporal checks, not untouched out of sample.

## Gate

DO_NOT_LAUNCH: USD February effect reverses; gold1.80 January remains negative; selected exploratory sample not pristine OOS

ORDER vs previous FILL ER drift: 0 / 131 entries. Full source-prefix invariance and old-FILL-feature parity passed.

See summary.json for day-cluster intervals and exposure proxies, direction_comparison.csv for side concentration, all_entries_order_time.csv for every removed winner/loss and missing case.
