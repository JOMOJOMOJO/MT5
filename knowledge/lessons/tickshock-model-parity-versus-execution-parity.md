# Model parity is not execution parity

In April technical discovery, all 3,967 causal feature/model outputs matched
between Python and MQL, and all 47,604 research barrier outcomes were unchanged
when the order adapter was added. Yet the deployed portfolio had 350 trades
against the research simulation's351 (347 shared keys).

The research engine sees the first real quote eligible after signal recognition.
A chart-driven EA can submit only when its dispatcher returns, using the then
available quote. Spread/cost guards, server exits, time-close scheduling and
global one-position conflicts can change downstream trades without changing
the model or using future features. TP price improvement and account-currency
conversion also make realized R differ from fixed price-distance R.

Reusable practice: prove feature/model parity separately; preserve request,
quote, fill and exit clocks; keep unmatched trades; reconcile tester report and
history fees; never replace actual fills with prettier research prices.

Development profit is a different question from generalization. The simple
candidate passed the user's development gate, while all four purged forward
diagnostics were negative. A positive same-month replay is not an OOS claim.

Evidence: [results](../../docs/research/tick_shock/technical_discovery_results.md)
and [actual differences](../../reports/backtest/runs/20260909_tstech_candidate_202504/trade_difference_causes.csv).
