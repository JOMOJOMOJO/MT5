# Early SL environment audit (read-only source analysis)

Selected population: ten distinct cells with PF > 1 in either existing execution scenario. Conservative `stop_first_lower` saved trades only; 2,666 closed trades, 2024–2025, no 2026. Results are post-selection descriptive statistics, not OOS or causal findings. Original files and trading rules were not edited.

## Denominator and fast winners

- Early nonambiguous SL: 752 / 1,345 losers = 55.91%; 752 / 2,666 all trades = 28.21%.
- Fast winners at holding_bars <= 2: 696 / 1,320 winners = 52.73%; 693 target and three target_gap_open; all nonambiguous.
- Thus early termination is not unique to losers. The current fixed TP/SL/ATR geometry needs to be considered before interpreting 56% as an entry failure rate.

| Family | All trades | Early SL | All losses | Fast wins | All wins |
|---|---:|---:|---:|---:|---:|
| ATR contraction breakout | 247 | 78 | 118 | 79 | 129 |
| Bollinger reversion | 971 | 260 | 492 | 216 | 479 |
| Donchian | 1,150 | 346 | 582 | 327 | 567 |
| Ichimoku cloud | 298 | 68 | 153 | 74 | 145 |

## Fixed pre-entry axes

Used `trend` for same-H1 EMA trend and `h4_trend` for H4. The saved `h1_trend` is unknown for H1 candidates by construction. Candidate available_time <= signal_time <= execution entry_time was checked; known H4 available_time <= signal_time checked. Volatility bins are the existing relative ATR bins low <= 0.8, normal <= 1.2, high > 1.2. No thresholds or combinations were searched. Unknowns remain explicit. Clock mapping is not asserted and no session condition was added.

Pooled early SL percentages:

- H1 aligned 408 / 1,469 = 27.8%, H1 opposed 344 / 1,192 = 28.9%.
- H4 aligned 398 / 1,443 = 27.6%, H4 opposed 330 / 1,163 = 28.4%.
- High relative ATR 140 / 545 = 25.7%, normal 468 / 1,654 = 28.3%, low 138 / 451 = 30.6%.
- Cloud above 28.0%, below 28.2%, inside 29.1%.

These pooled differences are too small and confounded by symbol/family/direction to claim a universal entry filter. In particular, 'only trade with the trend' is not supported as a blanket explanation.

## Within-cell differences worth examining, with counter-evidence

1. **AUDUSD cloud SHORT, H1 opposed**: early SL 35 / 125 = 28.0% vs aligned 33 / 173 = 19.1%. Early-rate difference persists in each year: +11.5 percentage points in 2024, +6.2 in 2025. But win rate advantage does not: 2024 opposed 23/63 = 36.5%, aligned 50/88 = 56.8%; 2025 opposed 31/62 = 50.0%, aligned 41/85 = 48.2%. Reducing early SL alone does not establish improved full-outcome returns.
2. **AUDUSD Bollinger SHORT, normal relative ATR**: early SL 45 / 252 = 17.9% vs other bins 32 / 104 = 30.8%. Normal is better on early-SL rate in both years (-10.9 and -14.7 pp); total win rate 53.2% vs 39.4%. Low-vol bin is only 31 trades (15 early losses, ten wins) so cannot treat its apparent weakness as a robust fine-grained filter. Normal's win rate declines from 59.7% in 2024 to 47.4% in 2025.
3. **USDJPY Bollinger LONG, normal relative ATR**: early SL 63 / 208 = 30.3% vs other bins 33 / 146 = 22.6%, opposite to AUDUSD Bollinger SHORT. Differences +2.2 pp in 2024 and +9.8 in 2025; win rates 46.6% vs 54.1%. Any volatility restriction must be condition-specific, not copied between instruments/directions.
4. **USDCHF Bollinger SHORT, high relative ATR**: early SL 13 / 52 = 25.0% vs others 74 / 209 = 35.4%; the difference is negative both years, but only 21 high-vol trades in 2024 and 31 in 2025. USDCHF covers 17 months only.
5. **USDJPY ATR LONG, H4 aligned**: early SL 32 / 101 = 31.7% vs others 8 / 41 = 19.5%, so higher-timeframe alignment does not universally reduce early loss. Small rest group and condition selection prevent a strong conclusion.

## Interpretation and limits

There are measurable differences for particular cells. They are correlations observed among a PF-selected set, not a model capable of identifying future losers. Features are highly dependent (e.g., cloud/H1 directions) and all displayed slices, not just promising ones, are saved in feature_slices.csv. No multiple-comparison-adjusted significance or independence is claimed. No counterfactual entry exclusion, overlap re-entry, new sizing, portfolio replay, or monthly stability improvement has been implemented.

Artifacts:
- [group_summary.csv](group_summary.csv): family/symbol/cell/year counts, early/late SL and winner counts.
- [feature_slices.csv](feature_slices.csv): all pooled, family, cell, cell-year slices and comparison denominators.
- [within_cell_comparisons.csv](within_cell_comparisons.csv): cell slices with both sides at least 40 trades, plus year-specific rates; descriptive shortlist only.
- [joined_trades.parquet](joined_trades.parquet): independently joined account ledger and causal context.
- [analyze.py](analyze.py): reproducible read-only analysis script.
- [qa.json](qa.json): population and holdout assertions.
