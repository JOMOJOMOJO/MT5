# 2026-03-31 EA Research Reuse Rules

- Date: 2026-03-31
- Scope: reusable findings from the BTCUSD redesign and session-mean-reversion work
- Source families:
  - `btcusd_20260124`
  - `btcusd_20260330_session_meanrev`

## Reusable Rules

- Do not trust a parameter region just because a short in-sample window looks clean.
  Locked validation and explicit OOS remain mandatory.
- Python validators are useful for narrowing search, but MT5 report-backed runs remain the promotion gate.
  Turnover and friction can diverge materially from the validator.
- A wider spread gate can lift trade count while still making the strategy worse.
  Trade count alone is not a promotion signal.
- Adding more entries on the same weak side of the book is often lower quality than adding an orthogonal bucket.
  The extra NY short bucket underperformed, while a late long bucket improved actual net/trades.
- Pattern explanation beats season labeling.
  If a weak window is explained only as "summer was bad", the model is not understood well enough yet.
- Live readiness requires operational controls, not just a profitable report.
  Daily caps, losing-streak cooldowns, telemetry, and forward-review rules are part of the strategy.

## How To Reuse This

- Cite at least one rule from this note when opening a new experiment family.
- If a future strategy breaks one of these rules, write down why the exception is justified.
