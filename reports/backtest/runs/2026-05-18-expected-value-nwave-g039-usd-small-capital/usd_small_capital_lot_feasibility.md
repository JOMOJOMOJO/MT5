# USD Small Capital Lot Feasibility

Broker/tester properties observed from diagnostics:

- Minimum lot: 0.01
- Lot step: 0.01
- Approximate margin for USDJPY 0.01 lot at 1:100 in this tester: 10 USD
- Accepted 0.01-lot risk sample count: 18
- 0.01-lot SL loss in USD: average 4.35, median 3.59, min 1.82, max 8.68
- 0.01-lot risk points: average 653.67 points, median 524.00, min 270.00, max 1307.00

## Can 0.01 Lot Be Placed?

- 100 USD: technically yes in the tester because 0.01 lot margin is about 10 USD, but margin headroom is thin once dynamic sizing tries to use more than 0.01 lot.
- 500 USD: technically yes, with more headroom than 100 USD, but aggressive 10% sizing still triggers many margin rejects.
- 1000 USD: technically yes and operationally cleaner under the safer 5/2/1 ladder.

## Effective Risk At 0.01 Lot

Using the observed 0.01-lot SL loss range:

- 100 USD: average 4.35%, max 8.68%
- 500 USD: average 0.87%, max 1.74%
- 1000 USD: average 0.44%, max 0.87%

Accepted min-lot-forced trades did not exceed 10% or 15% effective risk in this run. However, some candidates were blocked by `small_capital_effective_risk_too_high`, and many aggressive ladder candidates were blocked by margin insufficiency.

## Practical Judgment

100 USD and 500 USD can technically place 0.01 lot, but the account is too small for the aggressive 10/5/1 ladder to operate smoothly. The limiting factor is not only per-trade SL risk; it is also margin required for the dynamically calculated lot. 1000 USD is the first level where the safer ladder produced clean 2025 and 2026 Jan-Apr runs.
