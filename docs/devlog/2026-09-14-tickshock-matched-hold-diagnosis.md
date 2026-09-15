# Matched-entry hold diagnosis

User asked whether direction was correct but the five-minute exit was premature.
Compared saved runs without changing models/EA or running MT5. All 102 four-hour
trades have identical entry clocks/prices/volumes in the five-minute run.
Of the +566.78 USD aggregate improvement, +371.67 comes from matched holding
and +195.11 from not taking 177 extra five-minute trades. The day-cluster CI
for paired mean improvement contains zero; four-hour profitability disappears
after removing its top five winners. Do not infer a proven directional edge.

See `docs/research/tick_shock/two_stage_hold_direction_diagnosis.md` and
`reports/analysis/tick_shock/two_stage_hold_pairs_20260914/` for evidence.
Remaining question: full-population matched entry horizons and opposite-direction
Bid/Ask outcomes. No additional research run is authorized/inferred by this log.
