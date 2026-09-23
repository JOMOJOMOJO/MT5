# Entry timing experiment, fixed before results

Research only; existing EA/indicator and their defaults remain intact until evidence supports adoption.

## Arms
- current: existing READY, SL=confirmed M1 HL minus 10 points.
- hl: buy at first confirmed valid M1 HL, same HL stop rule.
- choch50: buy first closed M1 CHoCH when its confirmed reversal low is at/below the frozen M5 Wave1 midpoint and above M5 origin; SL=M1 reversal low minus 10 points.
- current_origin: existing READY with the same reversal-low stop as choch50 (stop control).

The 50% condition means the pullback reached 50%, not that the entry quote is still below midpoint. No Fib limit order. All arms preserve M5 origin invalidation, M5 breakout deadline, causal pivots, closed-bar signals, 1% planned risk, 15-minute fill cooldown, RR=1, one position, recovery protections. Mode 1 has no Wave1/HL fields at entry; these remain empty rather than fabricated.

## Windows and decision
- Synthetic causal/invalidation checks, then 2025-03-03 to 03-08 Model 4 smoke.
- Comparison: 2025-01-01 to 04-01, all four arms; known March 27 tick fallback must be reported.
- Locked holdout: 2025-05-01 to 08-01, preselect best eligible early arm based on comparison, compare to current. No tuning after holdout.
- Adoption requires positive net/PF>1 in comparison and holdout, increased trade count vs current, no worse equity drawdown, and clean execution/causality audits. Otherwise retain existing defaults and report rejected alternatives. No claim of live readiness.
- Current stop control isolates SL effects but candidate sets necessarily differ. Existing April results are already seen, hence not used as untouched holdout.

## Locked diagnostic extension before viewing May-July results

All early arms fail the positive comparison-net prerequisite. CHoCH50 nevertheless reduces the observed comparison loss/DD and increases trades (60 trades, -498.50, DD 8.63%, versus 46/-630.14/9.63%). On this evidence, lock CHoCH50 as the sole early arm for the planned May-July comparison against current. This is a diagnostic confirmation, not an exception to adoption criteria: a positive holdout cannot erase the failed comparison gate. No further input/logic tuning is allowed in this cycle.
