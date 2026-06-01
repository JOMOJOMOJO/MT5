# ExpectedValue Long-Only BucketLab

## Purpose

Create a comparison EA for long-only research without modifying the live short-only `ExpectedValue_NWave_Scalper.mq5` or the baseline `ExpectedValue_LongOnly_RelativeScalper.mq5`.

## Source

- New EA: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Baseline evidence: `reports/backtest/runs/2026-05-19-expected-value-long-relative-scalper-initial/summary.md`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab.log`
- Initial presets:
  - `reports/presets/ExpectedValue_LongOnly_BucketLab_usd100_initial_2025.set`
  - `reports/presets/ExpectedValue_LongOnly_BucketLab_usd100_initial_2026_jan_apr.set`

## Design Decision

The initial long-only relative scalper showed that the strict preset had positive expectancy but too few trades, while balanced/high-turnover settings degraded expectancy and moved toward drawdown-stop behavior. The BucketLab therefore avoids increasing frequency by loosening `Spread/ATR`.

The new EA keeps the strict-style quality gate and adds M1 execution under broader context:

- M1 execution timeframe
- M5 market-quality timeframe
- M15/H1 directional bias score
- H4 strong bearish avoidance
- No fixed session filter by default
- Weekday remains diagnostic/operational, not a time-of-day edge claim

## Buckets

Only two buckets are implemented for the first comparison cycle:

- `M1_PULLBACK_EXECUTION_LONG`
- `BREAKOUT_ACCEPTANCE_RETEST_LONG`

`FAILED_BREAKDOWN_RECLAIM` was intentionally not included in this pass because the first goal is to protect the strict continuation edge, not add a reversal bucket with higher accident risk.

## Risk And Exit

The baseline risk scaffold was retained:

- fixed-lot mode below equity threshold
- risk-percent sizing above threshold
- broker min/max/step lot normalization
- margin insufficiency block
- daily/weekly/DD/loss-streak stops
- max open positions
- total open risk cap
- averaging-down block
- cooldown
- timeout exit

SL/TP comparison is now explicit:

- `SL_ATR_ONLY`
- `SL_M1_SWING`
- `SL_M5_SWING`
- `SL_HYBRID`
- `TP_FIXED_R`
- `TP_RECENT_HIGH_OR_R`

## Diagnostics

The event log now includes bucket, entry reason, SL/TP mode, `Spread/ATR`, `ATR ratio`, `Range position`, `Body/ATR`, lower `Wick/ATR`, EMA distance/ATR, recent high/low distance in ATR, recent range/ATR, pullback depth/ATR, breakout acceptance/ATR, up/down pressure, hour, and day-of-week.

## Compile

`ExpectedValue_LongOnly_BucketLab.mq5` compiled with `0 errors, 0 warnings`.

## Next Validation

Use 2025 for development validation only. Use 2026 Jan-Apr as fixed OOS after candidate selection. Do not tune the 2026 Jan-Apr result.

## Initial 2025 Backtest Result

- Run folder: `reports/backtest/runs/2026-05-19-expected-value-long-bucketlab-initial-2025/`
- Summary: `reports/backtest/runs/2026-05-19-expected-value-long-bucketlab-initial-2025/summary.md`
- Environment: isolated portable MT5 under `C:/Users/windows/AppData/Local/CodexMT5BucketLab`

The initial 2025 preset completed with `9` closed trades, `+0.1333R` expectancy, PF `1.2838`, MaxDD `2.93%`, and no stop-condition events. It survived the USD 100 fixed-lot path, but it did not improve the primary objective because trade count was lower than the old strict baseline of `23` trades.

Decision: do not proceed to 2026 Jan-Apr OOS from this preset. Review 2025 design first, especially non-spread frequency bottlenecks such as range position, H4 avoidance, and bias score.

## Score-Regime BucketLab Revision

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_usd100_score_regime_2025.set`
- Accepted 2025 run: `reports/backtest/runs/2026-05-19-expected-value-long-bucketlab-score-regime-2025/summary.md`
- Loose-score failed control: `reports/backtest/runs/2026-05-19-expected-value-long-bucketlab-score-2025/raw/mt5_company_expected_value_long_bucketlab_score_2025_summary.csv`

Review finding: the initial BucketLab was not limited by MQL plumbing. It was limited by common AND gates and by treating quality filters as global hard filters before bucket-level hypothesis testing. Range position, H4 context, M15/H1 bias, trend, pressure, ATR regime, and candle shape now contribute to a bucket score instead of acting as shared hard gates.

Three research hypotheses were considered:

- `M1_PULLBACK_SCORE_LONG`: M1 reclaim after pullback, with relative-state scoring and a bucket-specific market-state requirement.
- `MICRO_BREAKOUT_ACCEPTANCE_LONG`: M1 breakout acceptance after M5 quality context, kept for later because the first breakout bucket had only one trade.
- `VOLATILITY_COMPRESSION_EXPANSION_LONG`: compression-to-expansion continuation, kept for later because it needs a separate compression feature set.

The implemented bucket is `M1_PULLBACK_SCORE_LONG`. A loose score-only pass failed: `113` trades, ExpectancyR `-0.2275`, PF `0.5994`, MaxDD `35.01%`, drawdown stop. That failure showed that a score threshold alone was not a sufficient market-state definition.

The accepted score-regime version requires one of two relative regimes before the score can trigger:

- discount pullback: M5 range position `0.25` to `0.45`
- ATR-expansion deep pullback: pullback depth at least `0.80 ATR` while ATR ratio is `1.45` to `1.80`

Accepted 2025 result: `119` trades, ExpectancyR `+0.1478R`, PF `1.3640`, MaxDD `12.46%`, max consecutive losses `5`, no daily/weekly/DD/loss-streak stop events, final balance `123.92 USD` from `100 USD`.

Decision: this revision is eligible for a controlled 2026 Jan-Apr OOS check next, without tuning on OOS. It is not a production candidate yet because trades/day is still only about `0.46`; the win is that the research framework now produces analyzable candidate logs and a non-ruin 2025 sample above the old strict trade count.

## candidate_v1 OOS Freeze And Result

- Candidate archive: `reports/backtest/candidates/expected-value-long-bucketlab-candidate-v1/`
- 2025 fixed rerun: `reports/backtest/runs/2026-05-19-expected-value-long-bucketlab-candidate-v1-2025/summary.md`
- 2026 Jan-Apr OOS: `reports/backtest/runs/2026-05-19-bucketlab-candidate-v1-oos/summary.md`
- Comparison: `reports/backtest/candidates/expected-value-long-bucketlab-candidate-v1/candidate_v1_comparison.md`

Before OOS, the EA log was extended with candidate metadata only: preset name, EA version, min-lot-forced flag, risk distance in pips, risk percent of equity, and free margin after entry. No entry condition, score threshold, SL/TP, spread, ATR, range, or risk-stop logic was changed.

The candidate_v1 2025 fixed rerun reproduced the score-regime result: `119` trades, ExpectancyR `+0.1478R`, PF `1.3640`, MaxDD `12.46%`, max consecutive losses `5`, no stop conditions.

The fixed 2026 Jan-Apr OOS failed: `9` trades, ExpectancyR `-0.3568R`, PF `0.4560`, MaxDD `9.00%`, max consecutive losses `7`, and loss-streak stop active. January was profitable, but February through April broke the edge. The main diagnostic failure was that the 2025-positive discount range state (`range_position 0.25-0.45`) did not transfer, and high ATR ratio / weak up-pressure states were particularly poor.

Decision: do not promote candidate_v1. Return to v2 research. Use the OOS only as a failure diagnosis, not as a parameter-optimization target.

## v2 Research Split And Guarded 2025 Result

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_research_guarded_2025.set`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab_v2_guarded_compile.log`
- 2025 run: `reports/backtest/runs/2026-05-19-expected-value-long-bucketlab-v2-research-guarded-2025/summary.md`

The v2 research pass split candidate_v1's `M1_PULLBACK_SCORE_LONG` into two separately logged bucket types:

- `DISCOUNT_RECLAIM_PULLBACK_LONG`
- `EXPANSION_PULLBACK_CONTINUATION_LONG`

The first v2 split confirmed the reason for the redesign: weak discount reclaim trades were the main 2025 drag, while expansion pullback continuation retained better expectancy. A guarded 2025 pass then made discount reclaim require stronger reclaim pressure and separated expansion from the discount range definition.

Guarded 2025 result: `54` trades, ExpectancyR `+0.2082R`, PF `1.5451`, MaxDD `10.41%`, max consecutive losses `5`, and no stop-condition events.

Decision: do not proceed to 2026 Jan-Apr OOS. Quality improved, but trade count fell below the v2 research requirement of `80` trades and below candidate_v1's `119` trades. The next 2025-only research step should add a non-overlapping bucket, preferably a micro breakout acceptance or continuation-entry bucket, rather than loosening `Spread/ATR` or re-admitting weak discount pullbacks.

## v2.1 Micro Breakout Research Result

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_1_micro_breakout_2025.set`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab_v2_1_compile.log`
- 2025 run: `reports/backtest/runs/2026-05-20-expected-value-long-bucketlab-v2-1-micro-breakout-2025/summary.md`

v2.1 added a third bucket, `MICRO_BREAKOUT_ACCEPTANCE_LONG`, without changing the production short EA, the long baseline EA, or the frozen candidate_v1 archive. The bucket requires M1 breakout acceptance, relative range context, pressure confirmation, ATR-regime control, R-efficiency checks, and a micro-specific breakout-structure SL. It does not loosen `Spread/ATR`, does not weaken discount reclaim, and keeps ATR ratio above `1.80` disallowed.

2025 result: `57` trades, ExpectancyR `+0.1855R`, PF `1.4674`, MaxDD `10.30%`, max consecutive losses `5`, and no stop-condition events. The added bucket itself was weak: `3` trades, ExpectancyR `-0.2222R`, PF `0.6667`.

Decision: do not proceed to 2026 Jan-Apr OOS. v2.1 remains non-ruinous and profitable overall, but it did not solve the trade-count objective and the new micro breakout bucket is not yet useful enough. Continue 2025-only research with better near-miss diagnostics or a different third bucket such as volatility compression expansion.

## v2.2 Compression Expansion Research Result

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_2_compression_expansion_2025.set`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab_v2_2_compile.log`
- 2025 run: `reports/backtest/runs/2026-05-20-bucketlab-v2-2-compression-2025/summary.md`

v2.2 kept the guarded discount and expansion buckets intact, turned `MICRO_BREAKOUT_ACCEPTANCE_LONG` off as a trading bucket, and retained micro only for near-miss diagnostics. The new trading bucket was `VOLATILITY_COMPRESSION_EXPANSION_LONG`, targeting short M1 compression followed by upside expansion while keeping `Spread/ATR` unchanged and ATR ratio capped at `1.80`.

2025 result: `57` trades, ExpectancyR `+0.1677R`, PF `1.4218`, MaxDD `10.80%`, max consecutive losses `4`, and no stop-condition events. The new compression bucket itself was weak: `3` trades, ExpectancyR `-0.5611R`, PF `0.1723`.

Decision: do not proceed to 2026 Jan-Apr OOS. v2.2 is still non-ruinous and profitable overall, but the added compression bucket does not solve the frequency objective and is not positive as a standalone bucket. The clearest bottleneck is that `EXPANSION_PULLBACK` generated many accepted signals but `max_open_positions=1` blocked most of them; the next research question should explicitly test whether capped two-position execution under total-risk limits improves trade count without damaging DD and loss streaks.

## v2.2 Two-Position Research Result

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_2_two_position_2025.set`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab_two_position_compile.log`
- 2025 run: `reports/backtest/runs/2026-05-20-bucketlab-v2-2-two-position-2025/summary.md`

This study did not add a new bucket. It kept `DISCOUNT_RECLAIM` and `EXPANSION_PULLBACK`, disabled `MICRO_BREAKOUT_ACCEPTANCE` and `COMPRESSION_EXPANSION` as trading buckets, and tested whether capped second entries could improve frequency. The second entry is allowed only for `EXPANSION_PULLBACK`, only when existing tracked positions are also expansion pullback, and not on the same M5 quality bar. The existing anti-averaging guard remains active, so a floating-loss managed long still blocks additional entries.

2025 result: `69` trades, ExpectancyR `+0.1818R`, PF `1.4386`, MaxDD `12.03%`, max consecutive losses `7`, and `2` max-consecutive-loss stop events. This is a frequency improvement over v2.2 (`+12` trades), but it still misses the `80` trade research target.

Position-layer analysis: first-position entries produced `42` trades at `+0.2733R` expectancy and PF `1.7406`. Second-position entries produced `27` trades at only `+0.0395R` expectancy and PF `1.0814`. The added exposure therefore did not collapse PF, but it was thin and introduced clustered loss-streak risk.

Decision: do not proceed to 2026 Jan-Apr OOS, and do not test three-position mode yet. The two-position preset already fired the loss-streak stop, so the next 2025-only research step should add a stronger second-entry throttle or require clearer continuation confirmation before a second `EXPANSION_PULLBACK` entry.

## v2.3 Second-Entry Quality Research Result

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_v2_3_second_entry_quality_2025.set`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab_second_entry_quality_compile.log`
- 2025 run: `reports/backtest/runs/2026-05-21-bucketlab-v2-3-second-entry-quality-2025/summary.md`

v2.3 keeps the two-position concept but changes the second entry from a repeated signal into a controlled continuation add-on. The first-entry bucket logic, `Spread/ATR`, discount reclaim guard, ATR ratio cap above `1.80`, SL/TP, and fixed-lot USD 100 assumption were not loosened.

Three second-entry control ideas were considered: require the first position to already be profitable in R terms, require a stronger expansion/pressure market state, and suppress second entries during loss streak or intraday drawdown. The implemented version combines those controls only when a managed position is already open.

2025 result: `58` trades, ExpectancyR `+0.2926R`, PF `1.8235`, MaxDD `9.90%`, max consecutive losses `5`, and no stop-condition events. Compared with raw two-position research, trade count fell from `69` to `58`, but second-entry quality improved from `27` trades at `+0.0395R` / PF `1.0814` to `8` trades at `+0.8121R` / PF `7.2871`.

Decision: do not proceed to 2026 Jan-Apr OOS. v2.3 is a rule-quality improvement, not a frequency solution. Keep the second-entry quality gate as a useful research control, but solve trade count through a separate first-entry source or a controlled sensitivity pass on second-entry gating before any OOS promotion.

## v2.4/v2.5 Frequency Research And OOS Failure

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab_shallow_continuation_compile.log`
- Exit-cadence sweep: `reports/backtest/runs/2026-05-21-bucketlab-v2-4-exit-cadence-sweep-2025/sweep_summary.csv`
- Controlled-stack sweep: `reports/backtest/runs/2026-05-21-bucketlab-v2-4-controlled-stack-sweep-2025/stack_sweep_summary.csv`
- Fast-exit sweep: `reports/backtest/runs/2026-05-21-bucketlab-v2-4-fast-exit-sweep-2025/fast_exit_summary.csv`
- v2.5 2025 fixed diagnostic: `reports/backtest/runs/2026-05-21-bucketlab-v2-5-2025-nearmiss-diagnostic/summary.md`
- v2.5 2026 Jan-Apr diagnostic: `reports/backtest/runs/2026-05-21-bucketlab-v2-5-oos-nearmiss-diagnostic/summary.md`

v2.4 tested frequency through holding-time, target-R, cooldown, and controlled stacking. Faster exit settings could reach the `80` trade target in 2025, but the edge became thin: the best fast-count probe reached `82` trades with only `+0.0523R` expectancy and PF `1.1966`. This was rejected as an operational direction because it improves count by compressing holding time, not by adding a robust independent edge.

v2.5 added `SHALLOW_CONTINUATION_PULLBACK_LONG`, a first-entry bucket for shallow M1 continuation pullbacks inside constructive M5 trend context. The selected 2025 candidate produced `76` trades, ExpectancyR `+0.2612R`, PF `1.9043`, MaxDD `8.21%`, max consecutive losses `3`, and no stop conditions. Bucket-level 2025 exit expectancy was:

- `EXPANSION_PULLBACK`: `60` trades, `+0.2175R`
- `SHALLOW_CONTINUATION`: `11` trades, `+0.4348R`
- `DISCOUNT_RECLAIM`: `5` trades, `+0.4038R`

This was a meaningful 2025 improvement over v2.3, but the fixed 2026 Jan-Apr OOS failed by absence of opportunity, not by drawdown: `1` closed trade, `-1.0R`, PF `0.0`, no stop condition. The losing OOS trade was a `SHALLOW_CONTINUATION` entry with ATR ratio about `1.74`, range position about `0.95`, and risk distance about `15.8` pips.

To avoid parameter fitting on OOS, the EA was extended with diagnostic-only `bucket_near_miss` logging. Trading thresholds, SL/TP, spread, ATR caps, and bucket rules were not changed. The OOS diagnostic found `167` near-miss rows, mostly `DISCOUNT_RECLAIM`-scored states that were not actually discount states (`range_position_outside_discount`: `102`) and expansion candidates blocked by high ATR / missing trend or pressure confirmation. This says the 2025-positive family is too regime-specific for the 2026 Jan-Apr window.

Decision: v2.5 is not deployable and must not be promoted. Do not tune thresholds to the OOS window. The next research cycle should either add a genuinely different market-state family that can be validated on a fresh development slice before OOS, or accept that this long-only USDJPY family is supplemental and may legitimately produce few trades in hostile regimes. Production readiness remains blocked until a fixed candidate survives an OOS window with adequate trade count and no loss-streak/DD stress.

## Final Check And Archive Decision

- Final check root: `reports/backtest/runs/2026-05-23-bucketlab-final-check/`
- Plan: `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_plan.md`
- Results: `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_results.md`
- Decision: `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_research_decision.md`
- Assets index: `reports/backtest/runs/2026-05-23-bucketlab-final-check/assets_index.md`
- Restart prompt: `reports/backtest/runs/2026-05-23-bucketlab-final-check/next_restart_prompt.md`

The final check intentionally avoided parameter optimization. It shallow-tested one new disabled-by-default family, `MID_RANGE_CONTINUATION_LONG`, plus SL/TP variants, a longer-hold M5/M15-leaning preset, and a stricter second-entry preset. All checks used 2025 only; no fresh OOS run was made because no variant solved the OOS opportunity-transfer problem.

Reference v2.5 rerun: `76` trades, ExpectancyR `+0.2612R`, PF `1.9043`, MaxDD `8.21%`, max losses `3`, no stops. The new mid-range family variant had `76` trades, ExpectancyR `+0.2687R`, PF `1.9554`, MaxDD `8.12%`, but the new bucket itself had only one trade and lost `-0.4634R`. It is therefore a research stub, not evidence of a new edge.

SL/TP checks showed HYBRID SL plus FIXED_R TP remains the best default for this family. M1 swing SL was slightly weaker; M5 swing SL reduced trades to `13`. A longer-hold `45` bar / `1.35R` preset improved R per trade but fired one loss-streak stop and reduced trades to `60`, so it is a separate-family hint rather than a promotion path. A stricter second-entry preset reduced trades and expectancy versus v2.5, so the existing v2.5 second-entry quality gate is the better retained control.

Final decision: archive `ExpectedValue_LongOnly_BucketLab` as a research asset. Do not deploy it, do not demo it, and do not promote any final-check preset. The best restart direction is a new market-state family discovered from bar data, preferably a longer-hold M5/M15 continuation thesis, with OOS used only after a candidate is fixed.
