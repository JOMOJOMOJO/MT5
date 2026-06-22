# Next EA Idea Bank From Multi-Currency Structure Research

Date: 2026-06-22

This file converts the closed Phase2 / ThirdWave / Nested N-Wave research into design assets for the next EA family.

## Design Position

Do not build the next EA as `ThirdWave v5` or another Nested Router threshold branch.

Build a new strategy family that starts from higher-timeframe structure and uses lower-timeframe triggers only after context is valid.

## Strategy Seed 1: Structural Context BOS

Working name:

`RESEARCH_STRATEGY_STRUCTURAL_CONTEXT_BOS`

Core thesis:

- H4 defines the dominant impulse and correction candidate.
- H1 defines the countertrend structure inside that correction.
- M15 confirms that the H1 countertrend structure has been invalidated.
- Entry is based on structural invalidation, not on a standalone M15 neckline candle.

Minimum questions before coding:

- What exact H4 structure defines the impulse?
- What exact H1 structure defines the countertrend correction?
- Which H1 pivot is the true BOS/invalidation level?
- Is there room to at least 1R and 2R before H4/H1 obstacles?
- Is the M15 trigger near the BOS or already chasing?

Why this is promising:

- It directly addresses the Structural BOS failure audit.
- It avoids over-reliance on M15 candle quality.
- It preserves the original N-wave idea while moving the edge definition up one layer.

Risk:

- If H4/H1 structure is too strict, trade count may collapse.
- If too loose, it becomes the same broad losing candidate pool.

## Strategy Seed 2: Liquidity Sweep After Valid HTF Context

Working name:

`RESEARCH_STRATEGY_HTF_CONTEXT_SWEEP_RECLAIM`

Core thesis:

- Sweep/reclaim is not an entry edge by itself.
- It may become useful only when it occurs at a valid H4/H1 correction end.
- The sweep must take liquidity around the countertrend structure, then reclaim the structural level.

Rules to explore:

- H4 impulse and correction must be valid first.
- H1 countertrend must have a clear recent extreme.
- M15 sweep must occur near the H1 countertrend exhaustion area.
- Reclaim must close back through the swept level.
- Entry must not be far from reclaim.

Why this is worth keeping:

- The last FX-only sweep/reclaim test failed broadly, but it was not context-first.
- Sweep/reclaim can still be a useful trigger if it is tied to the right participant stop area.

Risk:

- Without strong context it becomes thousands of losing trades.

## Strategy Seed 3: Context-Gated Pullback Continuation

Working name:

`RESEARCH_STRATEGY_CONTEXT_GATED_PULLBACK_CONTINUATION`

Core thesis:

- The best results often came from continuation-like entries rather than true third-wave initial entries.
- Instead of calling that ThirdWave, define it honestly as pullback continuation.
- Use H4/H1 trend context, require room to target, and measure whether continuation has positive expectancy.

Rules to explore:

- H4 trend must be active, not exhaustion/range.
- H1 pullback must be orderly and not break the structure origin.
- M15 reclaim or BOS can trigger, but only near pullback completion.
- `room_to_2R` starts as diagnostic, not a hard gate.

Why this is worth keeping:

- It aligns the label with what previous entries actually did.
- It may rescue useful continuation behavior without pretending to catch early wave 3.

Risk:

- It can become chasing-entry again unless distance from pullback extreme is audited.

## Strategy Seed 4: Obstacle-Aware Candidate Ranking

Working name:

`RESEARCH_STRATEGY_OBSTACLE_AWARE_RANKER`

Core thesis:

- `room_to_2r` was one of the most stable useful diagnostics, but not enough as a standalone gate.
- A ranking model may be better than a hard filter.

Candidate inputs:

- H4 bias
- H1 correction quality
- M15 trigger type
- room_to_1R
- room_to_2R
- distance from trigger to entry
- SL ATR
- nearest obstacle distance
- symbol/session volatility state

Important constraint:

- This must remain rule-based first. Do not jump to optimization or machine learning.

Why this is useful:

- It can turn all-candidates evidence into a best-candidate selector.

Risk:

- Easy to overfit if the ranking weights are tuned to 2025.

## Strategy Seed 5: Multi-Family Router By Context

Working name:

`RESEARCH_STRATEGY_CONTEXT_ROUTED_MULTI_FAMILY`

Core thesis:

- One trigger should not handle all market states.
- Different strategy families may be valid under different context types.

Potential routing:

- Trend continuation context: pullback continuation branch.
- Correction-end context: structural BOS branch.
- Liquidity sweep context: sweep/reclaim branch.
- Range context: no trade.
- Exhaustion context: no trade or reversal-specific branch.

Why this may be necessary:

- The same trigger behaved differently across 2024, 2025, and 2026YTD.
- Context quality, not entry candle quality, was the recurring issue.

Risk:

- A router can become a pile of fitted filters if context labels are not independently meaningful.

## Diagnostics To Include From Day One

- `strategy_family`
- `context_label`
- `h4_structure_state`
- `h1_counter_structure_state`
- `m15_execution_trigger`
- `room_to_1R`
- `room_to_2R`
- `nearest_obstacle_type`
- `entry_distance_from_structure_atr`
- `sl_atr`
- `result_R`
- `max_favorable_r`
- `max_adverse_r`
- `failure_type`
- `setup_failure_layer`

## Validation Ladder

1. Single fixed rule set.
2. Short-period diagnostic:
   - 2025-02
   - 2025-08
   - 2025-10
   - 2026-Q1
3. Require enough trades to avoid cosmetic improvement.
4. Split by FX vs XAUUSD.
5. Split by LONG vs SHORT.
6. If short gate passes, run annual:
   - 2024
   - 2025
   - 2026YTD
7. Do not promote if improvement is one year, one symbol class, or one direction.

## First Recommended Next Task

Recommended next task:

- Build a new `STRUCTURAL_CONTEXT_BOS` prototype as a separate EA research mode.

Reason:

- It attacks the repeated root cause: weak H4/H1 structure definition.

Minimal implementation:

- H4 impulse/correction sequence.
- H1 countertrend structure and true invalidation level.
- M15 closed confirmation of that H1 invalidation.
- Existing risk, spread guard, CTrade bridge, and fixed RewardR.
- Diagnostics first; no weekday/symbol/direction escape filters.

Stop condition:

- If short-period results are negative and failure audit still points to H4/H1 ambiguity, park this branch and do not tune M15 triggers.
- If improvement is only XAUUSD or one direction, treat it as diagnostic only.
- If trade count collapses below useful sample size, simplify structure definition before any parameter work.
