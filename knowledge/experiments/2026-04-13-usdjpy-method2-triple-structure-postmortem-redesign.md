# USDJPY Method2 Triple-Structure Postmortem And Redesign

## Scope

- Review the failed `triple-top short family` as a `standalone Method2` attempt.
- Do not rescue it by adding more confirmation.
- Split the failure into layers and redesign the next short-side research as separate theses.

## Baseline Read

- The family did not fail because it was too sparse.
- It failed because it produced enough trades and still lost after actual MT5 friction.
- Therefore the next step is not parameter retuning. It is hypothesis decomposition.

## Failure Decomposition

### 1. Thesis Failure

- The main risk is that classical `triple-top reversal short` simply does not scale well on this `USDJPY` feed.
- `USDJPY` often trends in orderly intraday continuation instead of producing repeatable, monetizable `ceiling reversal` swings at the granularity used here.
- The family could generate many nominal `triple-top` shapes, but those shapes did not carry a durable post-breakdown follow-through edge.
- Evidence:
  - enough trades were produced in all-day mode,
  - both `Strong only` and `Strong + Standard` stayed materially below the repo floor,
  - the positive subsets appeared only after collapsing into sparse hour pockets.

### 2. Context Failure

- The higher-timeframe context rule did not isolate true `exhaustion at the top`.
- To improve quality, the score map was moved away from upper-range bullish context and toward `mid-to-lower range`, `lower-high`, and bearish EMA structure.
- That repair created a contradiction:
  - if the context is truly top-heavy, the family is vulnerable to getting run over,
  - if the context is already weak enough to avoid that, the pattern stops being a classical top reversal and becomes a weak pullback short.
- In practice the family drifted away from `top reversal` and toward `generic weakness`, but without becoming a good pullback family either.

### 3. Entry Failure

- Entry logic likely waited for the wrong thing.
- `neckline close break -> market entry` is safe-looking, but it can be late on `M5`.
- By the time the breakdown is confirmed on close, a significant part of the immediate edge may already be spent, especially on `USDJPY`.
- The breakout-quality score also did not rank inventory well enough:
  - higher scores were not strongly monotonic,
  - mid-quality trades still passed too often,
  - `Strong + Standard` widened weak inventory rather than opening a second good bucket.

### 4. Exit Failure

- The exit package was mismatched to the entry horizon.
- Stop:
  - anchored above the highest of the three tops,
  - often wide relative to the immediate `M5` breakdown impulse.
- Target:
  - fixed `1.6R`,
  - likely too demanding for many short impulses that break the neckline but then stall.
- Time stop:
  - contained damage,
  - but most time-stop exits were still slightly negative or flat.
- Net effect:
  - stop losses remained the dominant damage source,
  - take-profits were too rare,
  - time stop acted more like a leak limiter than an edge expression.

## What To Keep

- `M15 x M5` as an initial research pairing.
  - It is fast enough to generate sample and slow enough to stay testable.
- Explicit split between:
  - thesis,
  - context,
  - entry,
  - exit.
- Telemetry-first review.
  - score, hour, range bucket, breakout type, stop distance, and exit reason were useful.
- Standalone evaluation.
  - this family should not be merged into Method1 as a partial survivor.
- Binary kill rule:
  - if a family has enough trades and still loses across windows, treat that as structural failure.

## What To Discard

- The assumption that `triple-top name` implies tradable edge.
- The current additive score map as a primary selector for this family.
- The `highest-of-three-tops` stop as the default stop for short breakdowns on `M5`.
- The idea that hour selection can rescue a structurally weak short family.
- Any attempt to widen the sample by admitting `Standard` inventory before a strong bucket has proven itself.

## Next Thesis Set

### Thesis A: Pure Classical Top Reversal Short

#### What it tries to capture

- True exhaustion at the top of an extended move.
- Reversal after repeated high failure and confirmed loss of support.

#### Where it should work

- Only in stretched, mature upswings.
- Best in sessions where a run-up has already occurred and upside continuation is visibly tired.

#### What invalidates it

- The third high is not actually late-stage extension.
- Price keeps accepting above the top zone after the break attempt.
- Breakdown lacks immediate downside continuation.

#### Entry / stop / target logic

- Entry:
  - not on arbitrary close break,
  - on breakdown of neckline plus immediate failure to reclaim.
- Stop:
  - above the failure/reclaim pivot, not necessarily above all three peaks.
- Target:
  - first target at prior swing low vicinity,
  - extension target only if downside impulse persists.

#### Why count can still appear

- Triple-top-like structures occur often enough on intraday data.
- Count comes from allowing a practical `quasi-triple-top` geometry, not from forcing perfect symmetry.

#### Difference from the failed family

- Treats the setup as `late exhaustion + failed support`, not as a generic scored pattern.
- Context must stay top-heavy.
- If that cannot survive, this thesis should be rejected quickly rather than softened.

### Thesis B: Failed Breakout / Liquidity Sweep Short

#### What it tries to capture

- Not the chart pattern itself, but the failed auction above resistance.
- Sweep of prior highs, rejection, return under the breakout line, then short.

#### Where it should work

- Around prior day high, session high, local swing cluster, or round-number extension.
- Best when the breakout is thin and quickly rejected.

#### What invalidates it

- Price accepts above the swept high.
- Reclaim under the level fails to hold.
- Breakout attempt is too small to be meaningful.

#### Entry / stop / target logic

- Entry:
  - sweep above level,
  - return under the level,
  - next-bar weakness or failure to re-extend.
- Stop:
  - above the sweep high.
- Target:
  - first target at mean-revert zone or prior intraday low,
  - optional fixed `1.0R-1.2R` if momentum is shallow.

#### Why count can still appear

- Liquidity grabs are more common than clean classical triple tops.
- The setup is structurally narrower but occurs across many local highs.

#### Difference from the failed family

- Focuses on `failed acceptance above a level`, not on 5-pivot symmetry.
- More execution-driven, less pattern-name-driven.
- Better aligned with short-lived `USDJPY` intraday reversals.

### Thesis C: Weak-Context Pullback Short

#### What it tries to capture

- A weak bearish trend resumption after a failed intraday rebound.
- No need to call it a triple top.

#### Where it should work

- Only when higher-timeframe structure is already weak:
  - lower high,
  - bearish EMA slope,
  - prior downside impulse exists.

#### What invalidates it

- Pullback regains the higher-timeframe mean cleanly.
- Rebound breadth is too strong.
- Downside impulse is not resuming after pullback failure.

#### Entry / stop / target logic

- Entry:
  - pullback into weak context,
  - local rejection,
  - continuation break under micro support.
- Stop:
  - above the pullback pivot.
- Target:
  - conservative continuation target,
  - likely `1.0R-1.2R` or prior local low.

#### Why count can still appear

- This is the most common short-side structure.
- Count is higher because it does not require a named reversal pattern.

#### Difference from the failed family

- Drops the claim that the trade is a top reversal.
- If this works, it should be treated as a different Method2 family, not as a rescue of the triple-top family.

## Ablation Design For The Current Method2

These are not rescue passes. They are isolation tests to prove which part of the failed family is actually responsible.

### Ablation 1: Remove scoring, use binary rules only

- Purpose:
  - test whether the score map is the main source of false positives.
- Design:
  - convert the current `Strong` rule into one hard binary rule,
  - no `Standard` bucket,
  - no weighted passing inventory.
- Read:
  - if expectancy does not improve, the problem is the underlying pattern, not the ranking layer.

### Ablation 2: Replace fixed `1.6R` target

- Variants:
  - prior swing low front-run,
  - ATR-linked target,
  - fixed `1.0R-1.2R`.
- Purpose:
  - test whether the family is right on direction but wrong on payoff distance.
- Read:
  - if time-stop losses shrink and tp count rises materially, exit mismatch was important,
  - if expectancy stays negative, the entry thesis remains weak.

### Ablation 3: Replace stop above all three tops

- Variant:
  - stop above the most recent breakout/failure pivot,
  - not above the full triple-top envelope.
- Purpose:
  - test whether stop placement is too structurally slow for `M5`.
- Read:
  - if stop-outs reduce and average `R` capture survives, the prior stop was too coarse,
  - if stop-outs rise sharply, local pivot placement is too noisy.

### Ablation 4: Replace neckline close break entry

- Variant:
  - intrabar neck break,
  - then next-bar failure to extend or reclaim failure confirmation.
- Purpose:
  - test whether close-confirmation is too late.
- Read:
  - if average stop distance falls and payoff improves without collapsing count, entry timing was part of the problem.

### Ablation 5: Timeframe-pair validity test

- Pairs:
  - `M30 x M5`
  - `M15 x M1`
  - `H1 x M5`
- Purpose:
  - test whether `M15 x M5` is the wrong fractal pairing for this thesis.
- Read:
  - if only one pair behaves sensibly, the thesis may be valid but scale-sensitive,
  - if all pairs fail similarly, the thesis itself is likely wrong for this symbol.

## Safe Evaluation Order

1. `Thesis A` binary-rule ablation
   - quick kill test for the pure classical reversal idea.
2. `Thesis B` standalone prototype
   - likely the highest-value next short thesis if a reversal family is still desired.
3. `Thesis C` standalone prototype
   - use only if we deliberately abandon the classical top-reversal claim.

## Decision Framework

- If `Thesis A` fails again after binary-rule and exit/entry ablations:
  - reject classical top reversal short on this symbol/timeframe family.
- If `Thesis B` works:
  - promote it as a new short family,
  - not as a repaired triple-top family.
- If only `Thesis C` works:
  - rename the family and stop using pattern language that implies top-reversal edge.

## Final Direction

- Keep the telemetry discipline and standalone gating.
- Drop the idea that the current triple-top implementation only needs tuning.
- The highest-value next test is `Thesis B: failed breakout / liquidity sweep short`.
- The cleanest kill test is `Thesis A` with binary rules and simplified exits.
