# BTCUSD Flow Filter Probe

- Features: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\research\2026-04-01-171300-btcusd-m5-feature-lab-spreadfix\analysis_window_features.csv.gz`
- Split date: `2026-01-02T10:10:00`

## Best Long Candidate

- `roc_atr_6 <= -1.3739` + `rsi7 <= 29.5772`
- Keep the long mask simple. Negative-flow or low-volume filters reduced turnover and usually did not improve OOS enough to justify them.

## Best Short Candidate

- `rsi7 >= 70.3714` + `ret_6 >= 0.0017` + `tick_flow_signed_3 >= 0.4176`
- Positive short-horizon flow improved OOS expectancy while keeping turnover high enough for a mainline prototype.

## Volume / Flow Interpretation

- Volume and flow are not symmetric.
- Long-side fades did not benefit from high-volume chase conditions.
- Short-side exhaustion became cleaner when strong positive flow was present first, which supports the idea of fading crowded upside extensions rather than fading every overbought print.

## Selected Rows

- `long_roc_rsi_base`: horizon `3`, filter `(none)`, train `41.37/day exp 0.0644`, test `43.51/day exp 0.0518`, test hit `55.84%`
- `long_break_high_base`: horizon `3`, filter `(none)`, train `45.58/day exp 0.0455`, test `46.93/day exp 0.0352`, test hit `55.98%`
- `long_break_high_flow_negative`: horizon `3`, filter `tick_flow_signed_3 <= -0.4165`, train `21.38/day exp 0.0518`, test `22.41/day exp 0.0316`, test hit `57.27%`
- `short_rsi_ret_flow_positive`: horizon `6`, filter `tick_flow_signed_3 >= 0.4176`, train `17.13/day exp 0.0007`, test `19.47/day exp 0.1420`, test hit `55.54%`
- `short_break_rsi_volume_low`: horizon `3`, filter `tick_volume_rel10 <= 0.7937`, train `6.19/day exp 0.0144`, test `4.58/day exp 0.1226`, test hit `57.25%`
- `short_rsi_ret_base`: horizon `6`, filter `(none)`, train `36.09/day exp 0.0143`, test `41.98/day exp 0.1152`, test hit `54.46%`
- `short_break_rsi_flow_positive`: horizon `3`, filter `tick_flow_signed_3 >= 0.4176`, train `18.20/day exp 0.0215`, test `17.56/day exp 0.1043`, test hit `57.30%`
- `short_break_rsi_base`: horizon `3`, filter `(none)`, train `40.33/day exp 0.0125`, test `37.35/day exp 0.0939`, test hit `56.65%`
