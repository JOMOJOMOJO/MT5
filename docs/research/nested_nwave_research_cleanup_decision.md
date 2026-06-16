# Nested N-Wave Research Cleanup Decision

Date: 2026-06-16

## Decision

Park the current Nested N-Wave Neckline Break family as an active promotion path.

Do not continue by adding more short-period thresholds, symbol suppressions, direction suppressions, or weekday/time filters. The current Nested definition produced useful diagnostics, but it did not prove a stable multi-currency edge.

## Evidence

- ThirdWave closure: `docs/research/thirdwave_research_closure.md`
- Initial Nested design seed: `docs/research/nested_nwave_neckline_break_design_seed.md`
- Nested Context Router RR 1.2 short summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_summary.md`
- Nested Context Router RR 1.2 annual summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_annual_summary.md`

The annual Context Router summary showed:

- `instant_all_r12`: PF `0.951`, avg_R `-0.014`, net `-275.87`.
- `context_router_v2_all_r12`: PF `0.867`, avg_R `-0.063`, net `-292.39`.
- `context_router_v3_all_r12`: PF `0.932`, avg_R `-0.026`, net `-135.95`.

V3 reduced drawdown by avoiding a specific weekend risk window, but it did not create positive expectancy. That makes it an operational risk-control observation, not a strategy edge.

## What Is Kept

These parts remain useful:

- multi-currency framework;
- both-direction evaluation;
- all-candidates entry research mode;
- lightweight diagnostics and summary counters;
- scan interval comparison framework;
- symbol, direction, session, month, regime, label, and R aggregation;
- breakout quality and context quality diagnostics as post-mortem tools;
- short-period gate followed by annual/OOS gate.

## What Is Deprecated

These are not mainline strategy logic:

- `RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3`
  - Deprecated compatibility alias.
  - No longer has Friday/time stop logic.
  - Should not be used as evidence of a universal edge.
- `context_router_v2_weak_body_too_small`
  - Kept only to reproduce V2 diagnostics.
  - Not a tuning direction.
- Friday 21:00+ entry stop
  - Removed from the EA strategy path.
  - If needed, it belongs to external operations policy, not structural expectancy logic.
- `InpDisableUsdJpyShort`
  - Research-only failure isolation switch.
  - Mainline research must keep it false.
- `SYMBOL_RESEARCH_XAUUSD_ONLY` / `SYMBOL_RESEARCH_FX_ONLY`
  - Research-only decomposition switches.
  - Mainline research must use `SYMBOL_RESEARCH_ALL`.
- `TRADE_DIRECTION_LONG_ONLY` / `TRADE_DIRECTION_SHORT_ONLY`
  - Useful for analysis, not proof of a universal branch.
  - Mainline research must start from `TRADE_DIRECTION_BOTH`.

## Why Not Tune Further

The failure pattern is not a single RewardR, SL, weekday, symbol, or candle-threshold problem.

The current Nested family can suppress losses by reducing trades, but it has not shown that it selects structurally superior entries across years and symbols. Another fixed M15 breakout threshold would mostly add overfit risk.

## Current Nested Family Status

| Branch | Status | Reason |
|---|---|---|
| Neckline Break instant | Research baseline | Strong in some windows, false-break prone. |
| Retest Confirmation | Research comparison | Reduces some losses but removes strong immediate breakouts. |
| Breakout Quality Router | Research diagnostic | Directionally useful, but mostly trade reduction. |
| Context Quality Router | Research diagnostic | Shows context matters, but not enough as implemented. |
| Context Quality Router V2 | Deprecated threshold branch | Short-period improvement failed annual robustness. |
| Context Quality Router V3 | Deprecated V2 alias | Friday guard removed; old result treated as ops-risk observation only. |

## Next Mainline Direction

Move away from M15 neckline appearance as the primary trigger.

The next mainline research candidate is:

`RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS`

That branch should use H4/H1 structure first:

- H4 defines 1-wave / 2-wave candidate more strictly.
- H1 defines the countertrend N-wave explicitly.
- M15 confirms a break of H1 countertrend structure.
- The trigger is H1 structural BOS, not an isolated M15 candle quality label.

## Guardrails For Next Work

- Do not use XAUUSD-only, FX-only, USDJPY-short-off, LONG-only, or SHORT-only as a promotion argument.
- Do not add weekday/time filters into strategy edge.
- Do not use RewardR or SL width tuning as the first fix.
- Do not write raw early-fail rows for every scan/symbol.
- Require short-period diagnostics before annual tests.
- Require annual separation across 2024, 2025, and 2026YTD before treating any branch as robust.
