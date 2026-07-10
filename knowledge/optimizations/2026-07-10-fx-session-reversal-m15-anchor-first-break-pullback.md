# M15 Anchor First-Break And True Pullback Optimization Note

## Fixed Variables

- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Tester period: M15
- Internal entry scan: `InpPrimaryEntryTF=PERIOD_M5`
- Context: `InpTopContextTF=PERIOD_H1`, `InpStructureTF=PERIOD_M15`
- H1 enum used in presets: `16385`, not `60`
- No symbol exclusion, direction-only repair, weekday stop, session-only promotion, TP/SL/BE optimization, or M5 ABC hard-gate repair.

## Tested Variants

- Baseline c10 and required-light reproduction.
- First-after-anchor diagnostic and required anchor flip.
- First-break fresh/normal age gate.
- True post-anchor pullback/retest diagnostic and required.
- True pullback + M5 reconfirm.
- Required-light OR true anchor pullback, with high/medium M5 pattern or corrective exhaustion variants.
- One-symbol reference variants.

## Findings

- The old latest-near-entry break and new first-after-anchor break differed in diagnostic trades by avg 2.8 M15 bars, max 15 M15 bars.
- The first-break correction did not rescue anchor flip expectancy: `anchor_flip_first_break` stayed negative at PF 0.76 / avg_R -0.0869.
- Fresh/normal age did not change the first-break required result in 2025.
- True post-break pullback/retest reduced losses versus baseline but did not become positive: `anchor_pullback_required` PF 0.90 / avg_R -0.0365.
- M5 reconfirm was stricter and worse: PF 0.75 / avg_R -0.0940.
- The best all-symbol integrated variant was still negative: `light_or_anchor_pullback_m5pattern` 104 trades / PF 0.96 / avg_R -0.0155.
- Positive fragments remained small: `required-light` and `one_light_or_anchor_pullback` were positive but under 100 trades or too narrow for promotion.

## Decision

Do not promote. Do not proceed to 3-year BT/OOS. Treat this as evidence that the current M15 anchor flip/pullback definition improves implementation fidelity but still does not isolate enough M15 3-wave launch quality across the full basket.
