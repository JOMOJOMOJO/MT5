# Next Phase Candidates

## 1. Entry Timing v3 / Wave-Position Gate

- Aim: stop entering after the move has already run.
- Failure cause addressed: lower timeframe reversal timing and chasing entries.
- Implementation difficulty: medium.
- Overfit risk: medium, controlled by short-period plus annual OOS gates.
- Expected improvement: higher average R, fewer late/chasing entries, cleaner wave labels.
- Evidence: Wave Audit classified 100 audited trades as `chasing_entry` and only 1 as `third_wave_initial`.
- Minimal change: add a separate research branch that requires the lower reversal to be close to the reclaim/breakdown and pullback extreme, and records the wave-position label before entry.
- Reason not to skip: this is the clearest root cause.

## 2. Regime Quality v2

- Aim: distinguish trend, range, transition, and exhaustion more strictly.
- Failure cause addressed: higher timeframe trend and regime classification.
- Implementation difficulty: medium-high.
- Overfit risk: medium-high.
- Expected improvement: fewer range/exhaustion trades.
- Evidence: regime-aware ThirdWave improved 2024/2026YTD but did not solve 2025.
- Minimal change: add trend-age, swing freshness, and exhaustion counters before entry.
- Reason to defer: current entries are still too late even inside allowed regimes.

## 3. Pullback Quality Filter

- Aim: reject shallow noise and deep trend-breaking pullbacks.
- Failure cause addressed: mid timeframe pullback quality.
- Implementation difficulty: medium.
- Overfit risk: high if thresholds are tuned.
- Expected improvement: fewer invalid structures.
- Evidence: v2 filters removed deep/old setups but over-filtered and concentrated XAUUSD.
- Minimal change: make pullback quality a diagnostic gate with fixed audit-derived bands.
- Reason to defer: v2 already showed this alone is not enough.

## 4. Multi-Symbol Candidate Ranking

- Aim: use All Candidates evidence to choose better candidates instead of only the top score.
- Failure cause addressed: research design and candidate selection.
- Implementation difficulty: high.
- Overfit risk: high.
- Expected improvement: avoid choosing weak symbols when multiple candidates pass.
- Evidence: All Candidates mode exposes hidden buckets but did not prove broad 2025 edge.
- Minimal change: rank only among candidates that pass a future wave-position gate.
- Reason to defer: ranking bad entries better still leaves bad entries.

## 5. Structure TP / Exit Diagnostics

- Aim: test whether fixed R exits are mismatched to structure.
- Failure cause addressed: SL/TP design.
- Implementation difficulty: medium.
- Overfit risk: medium.
- Expected improvement: better realized R if entries are valid.
- Evidence: fixed R may be inefficient, but entry quality is not yet proven.
- Minimal change: add exit-opportunity diagnostics without changing TP.
- Reason to defer: entry timing is the current bottleneck.

## Priority

1. Entry Timing v3 / Wave-Position Gate
2. Regime Quality v2
3. Pullback Quality Filter
4. Multi-Symbol Candidate Ranking
5. Structure TP / Exit Diagnostics
