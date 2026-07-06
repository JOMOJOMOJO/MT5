# Session Reversal Required-Light Adjacent Expansion Optimization Note

## Question

Can the positive `M15 wave2 required-light` fragment be expanded from 50 trades toward 100-200+ annual trades by relaxing only one nearby condition at a time?

## Tested

- Required-light original.
- Wave1 age only relaxation.
- Wave2 age proxy only relaxation.
- Shallow fib neighbor only.
- Deep fib neighbor only.
- Adjacent break type only.
- High-quality M5 near miss only.
- Context fib room near miss only.
- Q1-selected best-two combination.
- One-symbol research fragments.
- Diagnostic near-miss population.

## Findings

- Required-light remains positive but small: 50 trades, PF 1.34, avg_R +0.1099.
- Wave1 and wave2 age relaxation added only 5 trades and reduced avg_R to +0.0549.
- Deep fib neighbor and adjacent break type did not meaningfully expand the population; both matched the required-light result.
- Shallow fib neighbor expanded to 149 trades but failed: PF 0.66, avg_R -0.1341.
- High-quality M5 near miss expanded to 243 trades but failed: PF 0.70, avg_R -0.1123.
- Context fib room expanded to 143 trades but still failed: PF 0.90, avg_R -0.0345.
- The Q1-selected combination failed full-year validation: 147 trades, PF 0.65, avg_R -0.1393.
- One-symbol required-light remained positive but only 35 trades and is not promotable.
- Near-miss diagnostics show there are missed MFE>=1R trades, but the current nearby conditions do not separate them well enough.

## Rejected Promotion

No all-symbol row met the 2025 shallow gate:

- 200+ trades.
- PF >= 1.05.
- avg_R > 0.
- net > 0.
- no DD stop.
- no extreme dependency on one symbol, direction, or fragment.

`highq` reached 243 trades but had negative expectancy, so it is baseline leakage rather than a candidate.

## Reusable Lesson

The edge is not recovered by "almost required-light" conditions. The current required-light definition is a quality filter, but the rejected side still contains both good MFE trades and a larger losing distribution. The next valid research branch should add a new separator for the near-miss winners, not loosen the existing age/fib/context/M5 quality gates.
