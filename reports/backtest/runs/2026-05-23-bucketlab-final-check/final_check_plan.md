# ExpectedValue LongOnly BucketLab Final Check Plan

Date: 2026-05-23

Purpose: preserve the BucketLab research as a reusable asset. This is not a final optimization pass and not a production-promotion pass.

## Guardrails

- Do not modify `mql/Experts/ExpectedValue_NWave_Scalper.mq5`.
- Do not modify `mql/Experts/ExpectedValue_LongOnly_RelativeScalper.mq5`.
- Do not modify the frozen `candidate_v1` archive.
- Use 2025 as the main confirmation window.
- Do not use 2026 Jan-Apr OOS for parameter tuning.
- Run OOS only if a clearly improved fixed candidate appears.
- Do not increase frequency by simply loosening `Spread/ATR`.
- Do not add martingale, averaging-down, or 3-position execution.
- Treat any bankruptcy, repeated margin rejection, or early stop-condition trigger as a rejection.

## Theme 1: Alternative Market-State Family

Plan: add one disabled-by-default research bucket, `MID_RANGE_CONTINUATION_LONG`.

Hypothesis: the current family is too dependent on expansion/shallow pullbacks and disappears in 2026 Jan-Apr. A mid-range continuation family may capture constructive M5/M1 continuation where price is not in deep discount and not in extreme chase.

Scope:

- Add bucket inputs and logging only inside `ExpectedValue_LongOnly_BucketLab.mq5`.
- Keep existing buckets unchanged.
- Enable the new bucket in one 2025 preset.
- Do not tune the new bucket through repeated threshold optimization.

Do not:

- Relax `Spread/ATR`.
- Re-admit high ATR ratio above the existing safety regime without extra confirmation.
- Promote it from one 2025 pass.

## Theme 2: Short-Side Applicability

Plan: design review only.

Reason: there is already a production short-only EA. A rushed short prototype would risk confusing this long-only research asset with production behavior. The final check should document what can and cannot be mirrored.

Scope:

- Document mirrorable components.
- Document non-mirrorable assumptions.
- Recommend separate EA vs integration approach.

## Theme 3: SL/TP Comparison

Plan: run shallow 2025 comparisons against the v2.5 fixed candidate.

Variants:

- `HYBRID SL + FIXED_R TP`: existing v2.5 reference.
- `M1 swing SL + FIXED_R TP`
- `M5 swing SL + FIXED_R TP`
- `HYBRID SL + RECENT_HIGH_OR_R TP`
- `HYBRID SL + FIXED_R TP` with longer timeout / more M5-like hold.

Do not:

- Keep changing R until the result improves.
- Change spread filters or bucket definitions.

## Theme 4: M5/M15-Leaning Hold

Plan: use a small preset-level check rather than rewiring execution timeframe.

Reason: the EA currently assumes M1 execution arrays for bucket logic. A true M5 execution rewrite is a separate project. The final check should only test whether longer hold and slightly larger R improves stability.

Variant:

- `MaxHoldBars=45`, `TargetRMultiple=1.35`, `CooldownBars=6`.

## Theme 5: Second-Entry Throttle

Plan: compare current v2.5 second-entry gate with one more conservative gate.

Variant:

- Keep `MaxOpenPositions=2`.
- Keep second entry limited to `EXPANSION_PULLBACK`.
- Require day PnL not negative.
- Require higher open profit R before add-on.
- Require stronger up/down pressure and narrower risk distance.

Do not:

- Test 3 positions.
- Allow second entries while the first position is floating negative.
- Use OOS to select throttle thresholds.

## Deliverables

- `final_check_results.md`
- `final_research_decision.md`
- `assets_index.md`
- `next_restart_prompt.md`

