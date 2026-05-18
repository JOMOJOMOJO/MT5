# USD Small Capital Challenge Promotion Checklist

This checklist is for high-risk small-capital challenge testing only. It is not normal production approval.

## Minimum Conditions Before Real-Money Challenge

- Same broker/server demo with the same initial capital equivalent for at least 30-50 closed trades.
- No ruin flag.
- No unexplained `small_capital_margin_insufficient`; repeated margin insufficiency means the account size/risk ladder is not feasible.
- `effective_risk_percent_max` remains at or below `SmallCapitalMaxEffectiveRiskPercent`.
- Min-lot forced trades are understood and explainable.
- `AvgLossR` remains near -1R on actual live-path tester/deal logs.
- `live_order_send_failed`, `live_position_tracking_failed`, `live_sl_tp_invalid`, and `live_lot_invalid` are all 0.
- Deal-level logging is complete: actual entry/exit, realized R, commission, swap, slippage, spread, balance, equity, DD%.
- 0.01-lot USDJPY loss profile is understood: observed average 4.35 USD, max 8.68 USD in this test sample.
- Only money that can be fully lost is used.
- No additional deposit or risk increase before at least 30 real-money challenge trades.
- If equity reaches 1000 USD, the ladder automatically steps down to the second tier.
- If equity reaches 10000 USD, the ladder automatically steps down to the third tier.
- This challenge remains completely separate from controlled demo, small live, and production operation.

## Current Evidence-Based Gate

- 100 USD: demo feasibility only; real-money challenge not approved.
- 500 USD: demo feasibility only; real-money challenge not approved.
- 1000 USD: safer 5/2/1 demo can be considered; real-money challenge still requires 30-50 demo trades without margin issues.
- 10000 USD: technically feasible, but this should usually move back toward controlled risk, not high-risk challenge framing.

## Immediate Stop Conditions

- Any live tracking, SL/TP, lot, or order-send error.
- Any order without SL/TP.
- Any non-USD account when USD challenge mode requires USD.
- Repeated margin insufficiency.
- Effective risk above configured cap.
- Challenge hard stop or ruin DD reached.
- Logs stop writing.
