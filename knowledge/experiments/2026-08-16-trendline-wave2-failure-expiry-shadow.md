# TRENDLINE_WAVE2_FAILURE expiry shadow

## Hypothesis

The fixed 72-H1-bar setup expiry may terminate otherwise valid M15 anchors too early. Observe expired setups without changing trading eligibility or allowing orders.

## Method

- Strategy expiry remains 72 H1 bars.
- Expired setups are copied into an isolated shadow record.
- Shadow observation ends after at most 240 H1 bars.
- The observer records M15 swing counts, first counter-structure, shadow anchor, and H1 Wave-1-origin break.
- Shadow code cannot construct or open an order.

## 2024 result

- Shadows: 1
- Shadow anchors: 1
- Anchor before H1 origin break: 1
- No anchor within 240: 0
- Shadow order attempts: 0
- The anchor occurred 30 H1 bars after expiry and 103 H1 bars after the H1 break.

## Interpretation

The observation supports testing whether expiry is truncating some setups, but one occurrence is not a parameter-change basis. Preserve expiry=72 until additional locked windows produce a meaningful sample.

## Evidence

- [Raw shadow record](../../reports/backtest/runs/20260816_trendline_wave2_failure_execution_shadow/execution_shadow_2024/new_tw2f_execution_shadow_2024_expiry_shadow.csv)
- [Validation report](../../reports/backtest/runs/20260816_trendline_wave2_failure_execution_shadow/final-report.md)

