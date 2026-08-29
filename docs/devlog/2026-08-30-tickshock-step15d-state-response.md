# Tick-shock Step 15D state-response study

Step 15D added causal post-shock checkpoints and executable Bid/Ask path
recording without changing the frozen detector, state machine, strategy
parameters, RR, stop grid, or order behavior. The March replay preserved the
Step 15C event and funnel outputs exactly.

Development-data label patterns appeared for clean continuation and
failed-shock reversal, but both failed executable one-sigma cost screening.
Accordingly no state-rule hypothesis was promoted. See
[`15d_state_conditioned_response_results.md`](../research/tick_shock/15d_state_conditioned_response_results.md),
the [behavior comparison](../../reports/refactor/tick_shock/step15d_behavior_comparison.csv),
and the [candidate registry](../../reports/analysis/tick_shock/step15d/state_rule_candidates.csv).

The key lesson is that predictable future path labels are not sufficient when
the executable barrier is smaller than the entry-side spread. The research
pipeline must apply causal Bid/Ask screening before freezing a state rule.
