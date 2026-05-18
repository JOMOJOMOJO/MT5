# USD100 Lot And Margin Feasibility

Observed with the fixed 0.01 lot USD100 challenge test:

- 2025: 98 trades, final balance 150.50 USD, max DD 11.61%, effective risk max 7.01%, p95 2.72%, margin rejects 0.
- 2026 Jan-Apr: 39 trades, final balance 121.81 USD, max DD 8.11%, effective risk max 7.30%, p95 1.90%, margin rejects 0.
- 2024-2026 reference: 303 trades, final balance 148.09 USD, max DD 32.76%, effective risk max 8.72%, p95 3.35%, margin rejects 0.

The broker/tester minimum lot is 0.01. In this mode the EA never increases lot size from risk percent, so margin pressure is materially lower than the 5/2/1 or 10/5/1 ladders. Effective risk did not exceed 10% in accepted fixed-min-lot trades, and no trade reached the 15% hard block.

This does not mean 100 USD cannot fail. It means the tested g039 path did not produce a 95% ruin event under fixed 0.01 lot. The 2024-2026 reference drawdown of 32.76% is still large for a normal live account, but acceptable only if this is treated as a high-risk challenge where losing the 100 USD is allowed.
