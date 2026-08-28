# Tick-shock Step 15C event-response study

Step 15C added a bounded, production-path event-response recorder and replayed
March 2025 without changing the frozen detector or strategy rules. An initial
implementation extended the legacy statistical-track lifetime and changed one
weekend-gap strategy fill; the final r5 implementation freezes legacy state at
the original boundary and advances only the response recorder. The final
detector/funnel regression has zero differences.

Discovery showed a negative 10-second continuation return, but the one-shot
internal confirmation reversed sign and did not support it. No strategy
candidate was promoted. Fixed-horizon data was deliberately not used to invent
an arbitrary RR first-touch result.

Evidence:

- [results](../research/tick_shock/15c_event_response_results.md)
- [candidate registry](../research/tick_shock/15c_strategy_candidate_registry.md)
- [causal audit](../../reports/qa/tick_shock/step15c_causal_audit.csv)
- [final QA](../../reports/qa/tick_shock/step15c_final_qa.md)
