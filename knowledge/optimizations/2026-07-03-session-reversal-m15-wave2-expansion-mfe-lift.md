# Session Reversal M15 Wave2 Expansion Optimization Note

## Question

Can the `M15 wave2 required-light` quality improvement be expanded from 50 trades toward 100-200+ trades without losing MFE lift or expectancy?

## Tested

- Baseline c10 reproduction.
- Prior `m15_wave2_required_light` reproduction.
- Expanded M15 wave2 pullback-only gate.
- M15 wave1-or-wave2 context.
- M15 not-opposite plus pullback.
- M15 fib-or-structure pullback.
- M15 wave2 required only for low-quality M5 patterns.
- M15 wave2 required for medium/low-quality M5 patterns.
- One-symbol combinations.
- No-session diagnostic.
- Minimal exit comparisons: fixed TP/SL and shorter max-hold diagnostic.

## Findings

- Required-light remains the only clearly useful fragment: 50 trades, PF 1.34, avg_R +0.1099, avg_MFE 0.781R.
- Broad all-symbol M15 wave2 expansion recovered trade count but did not preserve expectancy.
- The best broad all-symbol row by avg_R was not-opposite plus pullback: 229 trades, PF 0.66, avg_R -0.1293.
- Expanded pullback-only reached 280 trades, but PF was 0.63 and avg_R -0.1446.
- M5 pattern quality gates did not solve the problem; low-quality and medium/low-quality gates behaved close to baseline.
- One-symbol expanded was positive but only 83 trades; keep it as a research clue, not a promotion candidate.
- Fixed TP/SL only increased MFE visibility but worsened realized expectancy through full SL exposure.
- Shorter hold reduced realized loss but also reduced MFE and TP rate, so it is not a structural entry improvement.

## Rejected Promotion

No 2025 shallow gate pass:

- No all-symbol candidate had 200+ trades, PF >= 1.05, avg_R > 0, net > 0.
- Tokyo, London, Clean, and one-symbol fragments are too small for promotion.
- 3-year fixed BT and OOS were not run.

## Reusable Lesson

The edge signal is probably not "any M15 pullback context." The stricter M15 wave2 required-light condition filters for a real quality difference, but the currently tested broadening rules are too permissive and mostly recover the losing baseline distribution.

Next research should avoid finer TP/BE/SL tuning and avoid M5 ABC hardening. If this family continues, the next valid branch should define a better M15 wave2 completion quality marker rather than making the existing pullback definition wider.
