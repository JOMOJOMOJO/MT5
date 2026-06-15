# Nested N-Wave Context Quality Seed

This note preserves the next design direction after the Router decision audit. It is not an implemented rule set.

## Two-Stage Router

1. M15 neckline break occurs.
2. Classify Breakout Candle Quality.
3. Classify Context Quality.
4. Route the candidate:
   - Strong breakout + clean context + room to 2R: instant entry.
   - Weak breakout + clean structure: retest confirmation.
   - Strong candle but overextended or blocked by nearby obstacle: retest or skip.
   - Dirty breakout, stale neckline, poor RR, or broken context: skip.

## Context Quality Inputs

- H4 wave-2 endpoint naturalness.
- H4 pullback zone and distance to next H4 obstacle.
- H1 counter N-wave break quality.
- M15 pre-break extension and whether the entry is already late.
- Neckline age and touch count.
- Neckline-to-entry distance.
- SL ATR width.
- Room from neckline to 2R and from 1R to 2R.
- False-return behavior after break, separated from healthy shallow retests.

## Guardrails

- Do not make this XAUUSD-only, LONG-only, or SHORT-only.
- Do not use hindsight false-break labels as direct live filters.
- Keep early fail rows summarized; do not return to full raw scan logging.
- Test fixed gates only after the audit shows which skipped candidates were truly poor.
