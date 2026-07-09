# M15 Swing Anchor Bias Optimization Note

## Hypothesis

The prior M15 wave2 required-light edge was too small to trade. The next hypothesis was that explicit M15 oshiyasu/modoritakane anchor-bias management could separate valid third-wave launches from weak continuation/reversal attempts.

## Fixed Inputs

- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD.
- Top context: `PERIOD_H1=16385`.
- Structure: `PERIOD_M15=15`.
- Primary entry: `PERIOD_M5=5`.
- Tester period: M15.
- Model: 4.
- Deposit: 10000.
- No symbol exclusion, direction exclusion, weekday repair, TP/BE/SL optimization, or M5 ABC hard-gate repair.

## Tested Variants

- Baseline c10 reproduction.
- M15 wave2 required-light reproduction.
- Anchor diagnostic only.
- Anchor aligned required.
- Anchor flip required.
- Anchor flip plus pullback.
- Required-light AND anchor aligned.
- Required-light OR anchor flip.
- Required-light OR anchor flip plus M5 pattern.
- Required-light OR anchor flip plus corrective exhaustion.
- One-symbol diagnostic variants.
- Range blocked and range required-light-only variants.

## Key Full-2025 Findings

- `full2025_base`: 318 trades, PF 0.59, avg_R -0.1582.
- `full2025_light`: 50 trades, PF 1.34, avg_R +0.1099.
- `full2025_anchor_aligned`: 222 trades, PF 0.65, avg_R -0.1327.
- `full2025_anchor_flip`: 122 trades, PF 0.76, avg_R -0.0869.
- `full2025_light_or_anchor_flip`: 145 trades, PF 0.79, avg_R -0.0760.
- `full2025_light_or_anchor_m5pattern`: 142 trades, PF 0.81, avg_R -0.0712.
- `full2025_light_or_anchor_exhaustion`: 108 trades, PF 0.77, avg_R -0.0854.

## Lessons

- Anchor aligned lifted MFE and TP rate slightly versus baseline, but not enough to overcome the negative expectancy.
- Anchor opposite is a useful bad-population diagnostic.
- Anchor flip is not enough to define the video-style transition entry; it still captures too many weak moves.
- Requiring post-flip pullback reduced count sharply and did not improve expectancy.
- Blocking `range_n` made results worse; range state should remain diagnostic for now.
- The current family still lacks a robust entry-quality separator that produces 100 to 200+ trades with positive expectancy.

## Decision

Do not promote any M15 anchor-bias candidate. Preserve the diagnostics, but do not continue tuning thresholds in this family unless a materially different entry-quality separator is introduced.
