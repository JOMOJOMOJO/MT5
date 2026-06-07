# ThirdWave Research Closure

Date: 2026-06-07

## Status

ThirdWave / nested third-wave / LowerTF SL research is closed from active research.

This is not a deletion or a failure label. It is a park-and-preserve decision: the work produced reusable framework, diagnostics, and negative evidence, but the current ThirdWave family should not receive further incremental tuning as the main strategy path.

## Research Purpose

The original question was whether a multi-currency EA could capture a practical third-wave entry:

- Higher timeframe Dow/fractal trend.
- Mid timeframe pullback or return.
- Lower timeframe reversal confirmation.
- Structure-based SL.
- Fixed-R TP.
- Multi-symbol and direction-separated diagnostics.

The later question was whether the same family could be repaired by moving entries earlier, filtering weak structures, selecting better reversal signals, or using LowerTF SL plus smaller R targets.

## Branches Tested

| Branch | Intent | Result |
|---|---|---|
| Phase2 multicurrency score scanner | Speed up testing, split direction/symbol behavior, add first structure gate | Useful. LONG and structure diagnostics were informative. BOTH remained weak. |
| LONG_ONLY / SHORT_ONLY split | Determine whether negative expectancy came from one side | Useful. SHORT branch was structurally weak in 2025; LONG was the cleaner branch. |
| DowFractalStructureFilter | Add trend/pullback/reclaim gate without changing core score logic | Useful as diagnostic. Improved LONG branch DD and PF in 2025, but did not prove broad robustness. |
| ThirdWave original | Separate third-wave style strategy branch from score scanner | Useful but not true early third-wave. Behaved mostly as structure-confirmed continuation. |
| Wave Audit | Label entry wave position and measure whether entries are early/middle/late/chasing | Critical. Showed chasing entries dominated. |
| ThirdWave v2 audit-filtered | Remove weak audit cases | Reduced weak structure cases but became narrower and more XAUUSD concentrated. Not promoted. |
| ThirdWave v3 entry timing | Gate entry position to remove chasing entries | Removed chasing, but kept only 4 of 109 comparable trades. Not viable. |
| ThirdWave v4 early reversal | Detect lower-timeframe reversal earlier than confirmed fractal reclaim/breakdown | Restored samples but did not improve PF/avg_R enough. |
| Reversal signal quality | Isolate micro_break, candle_reversal, and weak signals | micro_break and candle_reversal had pockets of value, but did not survive as standalone robust branches. |
| RewardR shadow 1.2/1.3/1.5 | Test TP sensitivity without changing live orders | Useful shadow evidence only. RewardR alone was not the root fix. |
| Current/MidTF/LowerTF SL shadow | Test whether lower-timeframe structure SL better matches entry thesis | Useful. LowerTF SL + 1.2R/1.3R looked promising in shadow. |
| LowerTF SL feasibility BT | Turn the strongest shadow hypothesis into small real BT | Short-term good, annual not robust. 2024 failed. |
| Signal / Regime Quality v2 | Diagnose why LowerTF SL worked in 2025/2026 but broke in 2024 | Useful closure evidence. Failure was regime/signal/pullback quality, not just SL/RewardR. |

## Main Results

### Phase2

- BOTH + 5m remained negative in 2025: PF `0.982`, net `-750.91`, max DD `36.06%`.
- LONG_ONLY + 5m was positive: PF `1.109`, net `3777.82`.
- LONG_ONLY + DowFractalStructureFilter was cleaner: PF `1.159`, net `3349.91`, max DD `6.64%`.
- SHORT_ONLY was structurally weak: PF `0.817`, net `-3428.37`.
- XAUUSD was a major profit source, so diversified robustness was not proven.

Evidence: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_summary.md`

### Wave Audit

- `third_wave_initial`: `1 / 109` trades.
- `third_wave_middle`: `5 / 109` trades.
- `chasing_entry`: `100 / 109` trades.
- Current ThirdWave is not a strict third-wave-initial model. It is closer to a structure-confirmed trend-continuation / chasing-entry model.

Evidence: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_summary.md`

### v2 / v3 / v4

- v2 reduced weak structures but cut the sample and increased concentration. It did not convert the model into an early third-wave entry.
- v3 removed `chasing_entry` but kept only `4 / 109` comparable trades. That is diagnostic proof that the existing detector rarely finds early entries, not a usable branch.
- v4 restored trade count with early reversal signatures, but short-period PF/avg_R did not beat the current ThirdWave baseline. Annual validation was not justified at that stage.

Evidence:

- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_short_period_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v3_short_period_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_short_period_summary.md`

### Reversal Signal / Shadow SL

- v4 signal branches did not improve actual PF/avg_R versus current ThirdWave.
- `micro_break` looked good inside all-signal v4, but did not survive isolation.
- `candle_reversal` had some value but remained XAUUSD-heavy.
- Shadow diagnostics showed `LOWER_TF_REVERSAL_SL + 1.2R / 1.3R` as the most interesting sensitivity result.

Evidence: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_short_period_summary.md`

### LowerTF SL Feasibility

- Short-period LowerTF SL looked good enough to test annually.
- Annual combined result was effectively tied with baseline:
  - Current ThirdWave current SL 1.5R: `542` trades, PF `1.075`, avg_R `0.059`, net `1148.02`.
  - v4 micro/candle LowerTF SL 1.2R: `699` trades, PF `1.075`, avg_R `0.059`, net `1342.92`.
- The LowerTF SL branch failed 2024:
  - 2024 current baseline: PF `1.139`, net `714.25`.
  - 2024 v4 micro/candle LowerTF SL 1.2R: PF `0.933`, net `-422.35`.
- It improved 2025 and 2026YTD but not enough to prove robustness.

Evidence: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_annual_summary.md`

### Signal / Regime Quality

- The 2024 break was not explained by a single direction, symbol, or RewardR/SL issue.
- It was a compound failure across regime, signal quality, pullback quality, session, and symbol behavior.
- 2025 success was mostly XAUUSD/LONG driven.
- 2026YTD success was more FX/SHORT driven.
- The success profile changed by year, so a simple fixed filter was not yet justified.

Evidence:

- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_signal_regime_quality_v2_summary.md`
- `reports/backtest/2024_failure_breakdown.md`
- `reports/backtest/2025_2026_success_breakdown.md`

## What Worked

- Multi-currency framework and per-symbol evidence collection.
- 5m new-bar scan and scan interval comparison.
- All-candidates entry mode for research visibility.
- Lightweight diagnostics and summary counters.
- Direction, symbol, regime, session, month, score-band, and wave-label aggregation.
- Wave Audit labels as a way to test whether the implementation matches the strategy thesis.
- Result in R (`result_R`, `avg_R`) as a normalized metric across symbols and SL styles.
- Shadow diagnostics for RewardR and SL location before changing live orders.
- Reversal signal classification.
- Spread guard and execution block diagnostics.
- Short-period gate followed by annual/OOS gate.

## What Failed

- Treating confirmed fractal reclaim/breakdown as sufficient for third-wave initial entry.
- Attempting to repair late entries by only filtering late/chasing cases.
- Expecting micro_break or candle_reversal to be robust as standalone universal triggers.
- Expecting LowerTF SL + 1.2R to generalize after a strong short-period result.
- Treating RewardR or SL distance as the root problem.
- Letting XAUUSD concentration make a weak multi-currency branch look better than it is.

## Hypotheses To Discard

- Current ThirdWave is an early third-wave entry model.
- Chasing entries can be made robust by a small fixed timing gate.
- v3-style strict entry-position filtering is viable as the next branch.
- v4 micro_break alone is a validated edge.
- LowerTF SL + 1.2R is enough to fix the family.
- A 2025-only improvement is enough evidence for this strategy family.
- XAUUSD-only or LONG_ONLY escape branches should be treated as general strategy improvements.

## Reusable Assets

- Multi-currency scanner framework.
- Research branch inputs for direction, symbol, strategy mode, entry selection, and diagnostics level.
- Scan interval framework.
- All-candidates entry mode for research.
- Lightweight CSV design: entry candidates, order attempts/results, execution blocks, and summary counters.
- Structure and regime diagnostic counters.
- Wave Audit label concept.
- R-based result aggregation.
- Shadow SL / RewardR feasibility process.
- Reversal signal taxonomy.
- Short-period gate to annual/OOS validation ladder.

Durable lesson file: `knowledge/lessons/thirdwave_lessons_learned.md`

## Do Not Reuse As-Is

- Confirmed fractal reclaim/breakdown-only entry.
- Broad chasing-entry acceptance under a third-wave label.
- XAUUSD-only specialization as proof of a multi-currency edge.
- LONG_ONLY or SHORT_ONLY specialization as proof of a universal strategy.
- 2025-fitting improvements.
- RewardR/SL-only repair attempts before regime and entry thesis are correct.
- Full raw diagnostic CSV for early failures on every scan and symbol.

## Closure Decision

Stop improving the current ThirdWave family as the active path.

Keep it as a research asset and negative-control family. The next strategy should not be "ThirdWave v5". It should be a separate model that uses the lessons but changes the thesis.

## Next Strategy Direction

Move to `Nested N-Wave Neckline Break`.

Core shift:

- Do not try to predict wave 3 directly.
- Identify a higher-timeframe correction candidate.
- Wait until the lower-timeframe countertrend inside that correction is invalidated.
- Enter after a neckline break or comparable stop-cluster break.
- Place SL where the new lower-timeframe reversal thesis is invalidated.
- Start with fixed-R TP for measurement, then diagnose exits later.

Design seed: `docs/research/nested_nwave_neckline_break_design_seed.md`

## Validation Policy For Next Family

- Start with fixed, explainable rules.
- Use all-candidates mode early to expose symbol/direction/regime behavior.
- Use short-period diagnostic gates before annual runs.
- Require 2024 / 2025 / 2026YTD separation before treating any result as robust.
- Do not promote if improvement is only XAUUSD, only one direction, or only one year.
- Keep raw diagnostics lightweight from the first run.

