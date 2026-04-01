# USDJPY Golden Method Validation

Use this as the always-on scorecard for the `USDJPY Golden Method` family.

## Doctrine Checks

- [ ] `EMA13` and `EMA100` are explicit in the candidate or the deviation is documented.
- [ ] Dow Theory trend judgement is explicit through swing highs / swing lows.
- [ ] The candidate distinguishes `follow-through` from `profit-taking` conditions.
- [ ] The transition line from the latest pullback high / low is explicit or a clear programmatic equivalent is documented.
- [ ] The volatility state logic is explicit.
- [ ] The repeated `50 pip zone` avoidance rule is explicit.
- [ ] Strategy 1 and Strategy 2 are distinguishable in code, notes, or both.
- [ ] Round-number breakout quality and fake-break avoidance are explicit.

## Operating Targets

- [ ] The candidate aims for about `1 trade/day`.
- [ ] The candidate aims for `20+ trades/month` on actual MT5 evidence, not only on Python approximations.
- [ ] Win rate is tracked, but expectancy after friction is the main gate.
- [ ] The monthly `12%` idea is treated as a reference, not as an optimization target that distorts the strategy.

## Risk And Deployment

- [ ] The baseline strategy risk model references the `2% per trade` doctrine.
- [ ] The repo deployment plan still respects capital-survival controls and hard loss caps.
- [ ] If the first real-capital preset uses lower than `2%`, the reduction is documented as a deployment safety choice rather than silent drift.
- [ ] The intended starting capital can express the strategy safely on the target broker.

## Validation Ladder

- [ ] A rolling `12 months = 9 months train + 3 months OOS` record exists.
- [ ] Long-window actual MT5 evidence is positive after realistic spread.
- [ ] Latest 3-month OOS actual MT5 evidence is positive.
- [ ] Trade count is large enough for the claimed edge.
- [ ] Demo-forward review exists before any live discussion.

## Promotion Rule

- Promote only if the candidate is both:
  - faithful enough to the Golden Method doctrine,
  - strong enough under repo live-ready rules.

If doctrine fit is high but execution metrics are weak, keep researching.
If metrics are high but the strategy has drifted away from the doctrine, record that explicitly instead of pretending it still is the same method.
