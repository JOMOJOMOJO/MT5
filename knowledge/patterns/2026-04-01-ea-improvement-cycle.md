# EA Improvement Cycle

- Date: `2026-04-01`
- Scope: reusable workflow extracted from the `btcusd_20260330_session_meanrev` improvement cycle

## What Actually Improved the Candidate

- The biggest gains did not come from adding more indicators blindly.
- The biggest gains came from:
  - killing losing branches early,
  - separating `quality` from `turnover`,
  - moving from Python-only optimism to actual MT5 evidence,
  - adding live guards only after the underlying edge survived,
  - parking a family once it stopped matching the business objective.

## The Cycle

1. Start from one explicit business objective.
   - Example:
     - `quality-first secondary live-track`
     - or `higher-turnover compounding mainline`
2. Mine behavior before tuning.
   - session behavior
   - regime split
   - directional asymmetry
   - friction sensitivity
3. Build one simple EA hypothesis.
   - one family
   - one market
   - one direction if necessary
4. Run a short search loop.
   - quick backtests
   - narrow ranges
   - reject obviously weak regions
5. Lock a candidate and run actual MT5.
   - 1-year actual first
   - latest 3-month OOS second
6. Decide what kind of problem it has.
   - if PF is weak:
     - rethink the algorithm
   - if PF is fine but friction kills it:
     - improve execution realism, spread control, or live guards
   - if PF is fine but trade count is too low:
     - do not overfit this family into a high-turnover role
     - start a separate higher-turnover family
7. Add live controls only after the edge survives.
   - daily loss cap
   - equity drawdown cap
   - pause / flatten
   - heartbeat
8. Run demo-forward.
9. Move to reduced-risk first capital.
10. Review quarterly and either:
   - promote,
   - park,
   - or kill.

## Decision Tree

- Add an indicator only when it solves a named defect.
  - Example:
    - a trend filter for obvious counter-trend damage
    - an ATR filter for dead sessions
- Change the algorithm when the current logic shape keeps failing across regimes.
- Start from chart and bar-data analysis when:
  - trade count is too low,
  - entry logic is not grounded in a repeatable market behavior,
  - or indicator stacking is becoming arbitrary.

## What Happened In This Repo

- Mixed direction failed.
- Short-side expansion failed.
- The long-only `bull37` branch survived.
- Live guards preserved the edge.
- The family remained too low-turnover for the main business objective.
- Correct decision:
  - keep it as a quality-first secondary family,
  - do not pretend it is the final high-turnover mainline.

## Automation Boundary

- Automate:
  - compile
  - tester runs
  - report import
  - OOS checks
  - forward gate evaluation
  - preflight
  - live review
  - git branch / publish flow
- Do not automate blindly:
  - whether to keep adding indicators
  - whether to redesign the whole algorithm
  - whether a low-turnover family should stay mainline

## Persistent Rule

- If the real problem is structural, stop tuning and open a new family.
