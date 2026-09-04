# Step 15M action-aligned feature catalog

## Contract

The source is the frozen Step 15L causal feature table. Every predictor is
available at or before `t0_msc`; future excursion and barrier columns are used
only to construct the action outcome. Continuation uses `action_sign=+1` and
reversal uses `action_sign=-1`.

## Direction transform

The following shock-direction-normalized values are multiplied by
`action_sign` and renamed from `_dir` to `_action` where applicable:

- `pre_return_5m_dir_atr`
- `m5_ema20_slope_dir_atr`
- `m15_alignment_dir`
- `pre_extension_15m_dir_atr`
- `day_range_position_dir`
- `confirmation_retention`
- `return_5s_dir_atr`, `return_10s_dir_atr`, `return_30s_dir_atr`
- `return_60s_dir_atr`, `return_120s_dir_atr`, `return_300s_dir_atr`,
  `return_900s_dir_atr`
- `accel_10s_vs_prev30s`
- `return_30s_vs_prev30s`
- `range_position_900s_dir`
- `distance_high_900s_dir_atr`
- `distance_low_900s_dir_atr`
- `momentum_efficiency_interaction`

`direction_consistency_30s_action` equals the original shock-direction
consistency for continuation and `1 - original` for reversal. This preserves a
0..1 fraction rather than turning it into a negative pseudo-fraction.

## Unchanged directionless fields

Spread/ATR, ATR14, tick activity, causal percentiles, detection efficiency,
severity, spread/flow efficiency interactions, lagged spread, spread changes,
tick counts and ratios, ranges, realized absolute movement, ATR slope, and the
unsigned deterministic interactions remain unchanged.

Categorical inputs are `candidate_direction`, `session`, and `action`. `symbol`
is used only by the explicit identity diagnostic. The original `shock_direction`
is retained as evidence but is not an additional model category because
candidate direction plus action already determines it.

## Registered groups

- `A_STEP15L_EXISTING`: the Step 15L existing causal inputs after action
  alignment.
- `B_ACTION_MOMENTUM`: A plus action-aligned price lags, acceleration, and
  consistency.
- `C_SPREAD_ACTIVITY`: B plus lagged spread and tick dynamics.
- `D_STRUCTURE_RANGE`: C plus range, realized movement, rolling structure, and
  ATR slope.
- `E_FULL`: D plus the frozen Step 15L deterministic interactions.

No March date/week, MFE, MAE, hit time, barrier result, realized R, or Clean
label is a predictor.
