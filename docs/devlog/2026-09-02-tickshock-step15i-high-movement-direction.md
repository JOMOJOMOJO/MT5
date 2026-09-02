# Tick-shock Step 15I: high-movement versus direction

Step 15I tested whether the low-spread/ATR, high-activity, high-ATR state that appeared in Step 15G can be separated into continuation and reversal using causal +60-second features.

The key engineering discipline was to build the three-condition filter from strictly earlier same-symbol observations. The filter increased registered 1.2R barrier-touch frequency but selected only 48 market clusters. Within those rows, 11 continued, 9 reversed and 28 timed out. Preregistered M15, momentum, range-position and agreement rules all produced negative diagnostic C2 R, so no directional rule was promoted.

Evidence:

- [research result](../research/tick_shock/15i_high_movement_direction_prediction_results.md)
- [pre-analysis registration](../research/tick_shock/15i_direction_prediction_preanalysis.md)
- `reports/analysis/tick_shock/step15i/`

Reusable lesson: a feature can be useful for opportunity sizing while containing little information about direction. Those two claims need separate labels, sample gates and verdicts.
