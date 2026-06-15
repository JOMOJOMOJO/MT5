# Nested N-Wave Router Decision Audit

## Scope

- This is a judgement audit of the existing Breakout Quality Router, not Router v2.
- No EA logic, order bridge, SL/TP, RewardR, timeframe, spread guard, or risk calculation was changed.
- The audit replays Router candidates that were skipped or blocked using the logged `entry_price`, `sl`, and `tp`.
- Same-bar TP/SL ambiguity is recorded and conservatively counted as SL for aggregate PnL.
- Primary interpretation uses `ALL_SCORE_PASSING`; `BEST_ONLY` is retained in CSV for traceability.

## Primary All-Candidates Decision Audit

| router_decision | candidates | win % | PF | avg_R | net | reached 1R % | reached 2R % | false return % | FX net | XAUUSD net |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| dirty_skipped | 133 | 31.58 | 0.942 | -0.053 | -245.4 | 51.13 | 31.58 | 60.9 | -258.9 | 13.5 |
| strong_blocked_existing_position | 1 | 100.0 |  | 2.0 | 96.84 | 100.0 | 100.0 | 100.0 | 0 | 96.84 |
| strong_blocked_spread_guard | 7 | 71.43 | 6.733 | 1.143 | 417.54 | 71.43 | 71.43 | 85.71 | 417.54 | 0 |
| strong_ordered | 8 | 37.5 | 1.263 | 0.125 | 59.29 | 62.5 | 37.5 | 75.0 | -49.63 | 108.92 |
| weak_routed_to_retest | 58 | 36.21 | 1.155 | 0.086 | 266.53 | 53.45 | 34.48 | 65.52 | 491.23 | -224.7 |

## Direct Answers

- `dirty_breakout` skipped candidates were net `-245.4` with PF `0.942` and avg_R `-0.053`. They were not uniformly bad, so `dirty` is too broad as a final discard bucket.
- `weak_breakout` candidates entered immediately would have produced net `266.53`, PF `1.155`, avg_R `0.086`. Retest routing should be audited with context quality, not treated as automatically safer.
- Blocked `strong_breakout` candidates: `8` candidates, net `514.38`, weighted avg_R `1.25`. Some losses were avoided, but this bucket also contains missed winners.
- Ordered `strong_breakout` candidates were sparse: `8` candidates, net `59.29`, avg_R `0.125`.
- 2025-10 removed hypothetical winners: `15` candidates.
- 2026-Q1 avoided hypothetical losers from dirty/weak routing: `82` candidates.

## Removed Winners / Avoided Losers

2025-10 removed winners by Router decision:
- `dirty_skipped`: 7 candidates, hypothetical net `638.4`.
- `weak_routed_to_retest`: 4 candidates, hypothetical net `393.56`.
- `strong_blocked_spread_guard`: 3 candidates, hypothetical net `293.51`.
- `strong_blocked_existing_position`: 1 candidates, hypothetical net `96.84`.

2026-Q1 avoided losers by Router decision:
- `dirty_skipped`: 57 candidates, hypothetical net `-2624.98`.
- `weak_routed_to_retest`: 25 candidates, hypothetical net `-1147.98`.

Interpretation:

- `dirty_breakout` is correctly removing many 2026-Q1 losers, but it also removed seven 2025-10 winners. Treating it as a hard final skip is too blunt.
- `weak_breakout` is close to breakeven overall and has positive 2025-08/2025-10 pockets, so retest routing should depend on context quality.
- Blocked `strong_breakout` candidates were often positive in this hindsight audit, but spread guard and existing-position blocks are execution constraints, not Router quality labels. Do not weaken execution guards based on this alone.

## Router Direction

- The current Router mostly reduces trade count; it is not yet reliably selecting winners.
- The next branch should not tune the current thresholds directly.
- The next useful design is a two-stage router: Breakout Candle Quality first, then Context Quality.
- Context Quality should decide whether a strong candle has room to run, whether a weak candle deserves retest, and whether a dirty candle is truly invalid.

## Context Quality Seed

- H4 pullback must look like a natural wave-2 endpoint, not range-middle noise.
- H1 counter N-wave must be structurally broken, not merely touched by one M15 close.
- M15 must not already be overextended before the neckline break.
- There should be enough obstacle-free room from neckline to 2R.
- Neckline age and touch count should penalize stale or over-tested levels.
- SL width should be acceptable relative to ATR.
- The path from 1R to 2R should be plausible; otherwise the router should choose retest or skip.

## Artifacts

- Audit CSV: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit.csv)
- By decision: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_by_decision.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_by_decision.csv)
- 2025-10 removed winners: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2025_10_removed_winners.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2025_10_removed_winners.csv)
- 2026-Q1 avoided losers: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2026_q1_avoided_losers.csv](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2026_q1_avoided_losers.csv)
- Context quality seed: [ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_context_quality_seed.md](ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_context_quality_seed.md)
