# Tick-Shock technical candidate: tester-only usage

## Program

`mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnicalCandidate.mq5`

This is a separate April-development candidate, not the research EA and not a
live-trading release. OnInit rejects any non-Strategy-Tester environment. Every
order-send adapter also checks MQL_TESTER. Normal live/demo charts cannot trade.
The user may backtest another period without retraining the frozen model.

The research-only entry point remains
`mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnicalResearch.mq5`.

## Fixed strategy

TAIL_V1_PERSISTENT creates an episode; `TSTechCapture` captures its 486 causal
completed-bar features. Two depth-3 trees estimate LONG and SHORT net R. Feature
values are quantized to the same 12 decimal places as the formal CSV, and
scikit-learn's float32 split comparison is reproduced in the exported model.

Choose LONG when its score exceeds SHORT and is >=0; choose SHORT symmetrically.
Exact ties or both scores below zero are NO TRADE. The selected model is
`g3_SHALLOW_TREE_absolute_0`; its complete preprocessing/trees are preserved in
`reports/analysis/tick_shock/technical_discovery/candidate_model.json` and the
generated `mql/Include/TickShock/TickShockTechnicalModel.mqh`.

TP=SL=1.0 completed M5 ATR14 at t0, outward-rounded to tick size. Reject distance
below three current spreads or broker stops violations. No stop widening to
obtain a fill. Target holding time is 900 seconds after entry. TIME is checked
on the EURUSD driver; market closure/quote gaps can prevent exact-second closing.
Server SL/TP remain in place throughout. No trailing, breakeven, averaging,
martingale or simultaneous positions are implemented.

## Execution difference from research replay

The snapshot callback only records/queues an intent. After the original global
dispatcher returns, the candidate obtains SymbolInfoTick for the target symbol.
It waits for a quote after t0/source quote and not before signal recognition plus
submit latency. Quotes older than the configured freshness limit are not used.
It sends market orders only at the current available side. It does not send an
order inside the historical quote replay loop.

Therefore exact model parity does not imply exact entry-price or trade parity.
The research first-eligible quote may have occurred between driver callbacks.
Server TP can improve on the conservative research limit price; server SL and
market TIME fills must be measured, not replaced with hypothetical barrier fills.
`python_trade_comparison.csv` in the candidate run explicitly retains differences.

Global one-position/pending protection is conservative. Any other position or
order blocks entry. The adapter only closes positions with its dedicated Magic.
FOK is preferred, otherwise IOC; it does not leave a GTC entry remainder. Actual
entry/exit deal volumes and weighted prices are aggregated by position identifier
from tester history. Full-close balance, realized fees and remaining positions
are checked. This is not a restart-enabled live execution service.

## Risk and operation

- `InpTechnicalRiskMoney=10.0`: target maximum price-to-SL loss in account currency.
- Per-entry budget is additionally capped at 0.25% of current equity.
- Lot is rounded down to VolumeStep; below minimum is skipped, not rounded up.
- `InpTechnicalMagic=260909731`: dedicated tester identity.
- OrderCalcProfit, OrderCheck and OrderSend retcodes are checked.
- The initial structural SL is protected; fill slippage exceeding 105% of the
  budget or intended distance triggers an execution guard. SL is never widened.
- TP is corrected outward from actual fill/SL if necessary.
- OnDeinit blocks new intents, closes owned positions, then writes evidence.

Use the candidate run's recorded preset and tester configuration as the starting
point, and change RunId/log folder/source hash metadata for every fresh run.
No implicit CSV append is allowed. The existing legacy reward-risk input remains
1.2 for inherited side research; this candidate's own geometry is fixed 1:1.

## Limits

The model was fitted and selected on April. Even a positive same-month actual
tester result is development evidence only. Purged forward diagnostics were
negative in all four folds for this rule. The descriptive selected-sample
bootstrap interval crosses zero. Do not infer OOS edge or live readiness.
There is no daily-loss/restart production service or real-broker execution
validation in this tester-only candidate. The next period test should preserve
the model/threshold/geometry and report failures as well as successes.
