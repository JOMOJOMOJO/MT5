# Small Live Promotion Checklist Updated

Status: blocked until controlled demo evidence exists.

## Required Before Small Live

- Controlled demo has at least 30-50 closed trades.
- Realized ExpectancyR > 0.
- PF > 1.05.
- AvgLossR is near -1R.
- live errors = 0.
- Deal-level logging is complete for every trade.
- MaxDD% is inside plan.
- Period R stop behavior is explainable.
- Soft/Hard/Emergency DD% stops behave as designed.

## Initial Small Live Risk

- Start RiskPercent at 0.05%-0.10%.
- Do not raise to 0.25% until at least 30 small-live trades are reviewed.

## 100 USD Exception Policy

No automatic exception is approved in the EA. A 100 USD account may be unable to place trades at 0.05%-0.10% risk if the broker minimum lot is 0.01 and the stop distance is not very small. Before any small-live exception:

1. Confirm symbol minimum lot and volume step.
2. Confirm USDJPY contract size and tick value for the exact account type.
3. Calculate minimum-lot risk for recent g039 stop distances.
4. Allow small live only if minimum-lot risk remains inside the approved risk budget or the owner explicitly accepts the oversize risk in writing.

If minimum lot forces risk materially above plan, use a demo account, larger balance, or nano-lot broker instead.
